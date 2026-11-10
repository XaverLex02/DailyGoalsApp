# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Zweck der App

DailyGoals ist ein persönlicher **Gewohnheits-Tracker** (iOS, SwiftUI). Kernidee: Man definiert 1–5 tägliche Ziele (z. B. Lesen, Sport, „No YouTube“) und hakt pro Tag ab, ob sie erreicht wurden. Ziele sind binär (erledigt / nicht erledigt) – keine Mengen, Dauern oder Teilerfüllung.

Produktziele, an denen sich Änderungen messen lassen sollten:

1. **Schnelles tägliches Abhaken** – Tagesansicht öffnen, Ziele antippen, fertig (Haptik + Animation als Feedback).
2. **Nachtragen** – die letzten 30 Tage plus heute sind über den Datums-Slider editierbar; Zukunft ist bewusst nicht auswählbar.
3. **Motivation durch Streaks** – Gesamt-Streak (alle Ziele erfüllt) in der Toolbar, Einzel-Streaks pro Ziel in der Analyse. Ein noch nicht erfüllter heutiger Tag bricht die Streak nicht (Zählung beginnt dann bei gestern).
4. **Rückblick / Muster erkennen** – Monatsquoten, Wochentags-Verteilung, häufigste Zielkombinationen, 6-Monats-Matrix.
5. **Erinnern** – optionale tägliche lokale Benachrichtigung zu einer festen Uhrzeit.
6. **Datenhoheit ohne Backend** – alles lokal in UserDefaults; Backup/Umzug nur per JSON über die Zwischenablage. Kein iCloud, kein Server, keine Accounts.

## Build & Run

Native iOS-App, gebaut ausschließlich über Xcode (kein SPM, kein Makefile, keine Skripte, keine externen Abhängigkeiten):

- **Bauen:** `xcodebuild -project DailyGoals.xcodeproj -scheme DailyGoals -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- **Tests:** `xcodebuild test -project DailyGoals.xcodeproj -scheme DailyGoals -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- **Einzelner Test:** `-only-testing:DailyGoalsTests/TestClassName/testMethodName` anhängen

Hinweise:
- Das aktive Developer-Verzeichnis ist auf dieser Maschine die Command Line Tools-Instanz → für `xcodebuild`/`simctl` `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` setzen.
- Simulator braucht iOS ≥ 26.2 (ältere Runtimes werden abgelehnt). Verfügbare Geräte: `xcrun simctl list devices available`.
- Onboarding testen: App deinstallieren (`xcrun simctl uninstall <SIM> tixen.DailyGoals`) und neu installieren. Bestandsnutzer simulieren: `testdata.json` als `goalsHistory` (Data) in `Library/Preferences/tixen.DailyGoals.plist` des App-Containers schreiben.
- **Es gibt aktuell keine Tests.** Die Targets `DailyGoalsTests` / `DailyGoalsUITests` existieren noch im `project.pbxproj`, ihre Quellordner wurden aber gelöscht (Commit `fecdb0e`). Es gibt kein geteiltes Scheme (`xcshareddata` fehlt) – Xcode erzeugt es automatisch.
- Das Projekt nutzt **explizite Dateireferenzen** (keine synchronisierten Ordner): Neue Swift-Dateien müssen im `project.pbxproj` bzw. über Xcode dem Target hinzugefügt werden, sonst werden sie nicht kompiliert.
- Build-Settings: `IPHONEOS_DEPLOYMENT_TARGET = 26.2`, `SWIFT_VERSION = 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (alle Typen sind implizit `@MainActor`). Bundle-ID `tixen.DailyGoals`.
- `testdata.json` (Repo-Root) enthält Beispiel-History im **alten** Format (Keys `lesen`, `sport`, `noyt`, `aufstehen`, `lernen`, 2025-10-01 bis 2026-02-28). Wird beim Start und beim Import automatisch auf die UUIDs der Standardziele migriert.

## Architektur

**Pattern:** MVVM mit SwiftUI; zwei verschiedene Observable-Mechanismen parallel im Einsatz.

### Datenschicht

`GoalsStore` (`Views/Tracker/GoalsStore.swift`, liegt trotz Model-Charakter im Views-Ordner) ist die einzige Datenquelle für Ziele und History – eine `@MainActor`-Klasse (`ObservableObject`), die als `@StateObject` in `DailyGoalsApp` erstellt und per `.environmentObject()` weitergegeben wird.

- **Persistenz:** `@AppStorage("goalsHistory")` und `@AppStorage("goals")` speichern JSON-`Data` in UserDefaults. `@AppStorage` außerhalb von Views löst kein Update aus → jeder Setter ruft manuell `objectWillChange.send()`.
- **History-Format:** `[String: [String: Bool]]` — äußerer Key Datum (`yyyy-MM-dd`), innerer Key `goal.id.uuidString`, Wert Abschluss-Status. Fehlender Eintrag = nicht erledigt.
- **Goals-Format:** `[Goal]` — max. 5, min. 1 Ziel (in `addGoal`/`removeGoal` erzwungen, UI blendet Buttons entsprechend aus).
- `history` und `goals` werden in `_historyCache` / `_goalsCache` gecacht; Schreiben nur über die Setter (aktualisieren Cache + UserDefaults). `goals` fällt bei Dekodierfehler still auf `Goal.defaults` zurück.
- `removeGoal` löscht auch alle History-Einträge des Ziels unwiderruflich.
- **Migration:** `migrateIfNeeded()` (im `init`) läuft nur, wenn `goals` leer/undekodierbar ist. Die eigentliche Key-Umschreibung (`GoalType.rawValue` → feste UUIDs via `Goal.migrationMap`) steckt in `GoalsStore.migrateLegacyKeys(_:)` und wird auch beim Import genutzt.
- **Import/Export:** Export-Format ist `GoalsStore.Backup` = `{"goals": [Goal], "history": {...}}` (pretty-printed, sortierte Keys). `importJSON` akzeptiert dieses Format (ersetzt Ziele **und** History) oder das alte reine History-Dictionary (ersetzt nur History, migriert Legacy-Keys). Validiert: Datums-Keys müssen `yyyy-MM-dd` sein, 1–5 Ziele.
- **Statistik-Basis:** Quoten zählen jeden Kalendertag ab `firstTrackedDay` (frühester History-Eintrag, gecacht) bis heute; fehlender Eintrag = nicht erledigt.
- **Analytics:** `analyticsSnapshot(range:)` liefert einen gecachten `AnalyticsSnapshot` (Cache wird in den Settern von `history`/`goals` und bei Tageswechsel geleert). Die Monatsmatrix nutzt separat `monthlyRate(for:month:)`.
- **Performance – wichtig:** Nach dem ersten Öffnen bleibt `AnalyticsView` im `TabView` am Leben und ihr `body` läuft bei **jeder** Store-Änderung, also bei jedem Abhaken im Tracker. Deshalb:
  - `AnalyticsView` rechnet nur, solange sie sichtbar ist (`isVisible` via `onAppear`/`onDisappear`, Refresh per `onReceive(store.objectWillChange)`), und hält Ergebnisse in `@State`.
  - Die Darstellung steckt in `AnalyticsContent` (`Equatable` + `.equatable()`), die SwiftUI bei unverändertem Snapshot überspringt. Neue Sektionen dort einhängen und nur Daten aus Snapshot/Matrix verwenden, **nicht** direkt auf `store` zugreifen.
  - Kein `DateFormatter`-Parsing über alle History-Keys pro Aufruf; Abgeleitetes cachen und in den Settern invalidieren.
  - Referenz (3 Jahre Daten, Analyse-Tab vorher geöffnet): Abhaken ~20 ms. Vor den Optimierungen ~2 s.
- `resetApp` löscht History, stellt `Goal.defaults` her, setzt Theme zurück und deaktiviert/storniert Erinnerungen (Onboarding wird **nicht** erneut gezeigt).

`AppSettings` (`Models/AppSettings.swift`) – `@Observable`-Klasse (Observation Framework), per `.environment()` weitergegeben (nicht `.environmentObject()`). Persistiert jede Property per `didSet` direkt in UserDefaults (Keys: `hasLaunchedBefore`, `colorScheme`, `notificationsEnabled`, `notificationHour` (Default 20), `notificationMinute`). `notificationDate` ist eine berechnete Hilfs-Property für `DatePicker`-Bindings.

### Datenmodelle

- `Goal` (`Models/Goal.swift`): `Identifiable & Codable & Equatable`-Struct mit `id: UUID`, `name`, `colorHex` (`#RRGGBB`), `symbol` (SF Symbol), optional `description` (nur im Editor sichtbar, siehe `docs/superpowers/specs/2026-03-30-goal-description-design.md`). Fünf Standardziele in `Goal.defaults` mit fest codierten UUIDs (`A1B2C3D4-000N-…`) – **diese UUIDs nie ändern**, Migration hängt daran.
- `AnalyticsSnapshot` (`Models/AnalyticsSnapshot.swift`): alle Analyse-Werte für einen `AnalyticsRange` (`days30`, `months3`, `months12`, `all`), in **einem** Durchlauf über die Tage berechnet (`GoalsStore.computeAnalyticsSnapshot`). Granularität: 30 Tage → Tag, 3 Monate → Woche (Mo-Start), 12 Monate → Monat, Gesamt → Monat bzw. Quartal ab > 24 Monaten. Enthält Buckets (Quote je Ziel + gesamt), Gesamtquote, Vorperioden-Quote (gleich lang, direkt davor; nicht bei „Gesamt“), Wochentage, Top-Paare und Streaks.
- `NotificationManager` (`Models/NotificationManager.swift`): statische Helfer, eine wiederholende `UNCalendarNotificationTrigger`-Notification mit fester ID `dailyGoalsReminder`.

### App-Start & Views

`DailyGoalsApp` setzt Theme (`preferredColorScheme`), plant beim Start die Notification neu (falls aktiviert) und zeigt `OnboardingView` als `fullScreenCover`, solange `hasLaunchedBefore == false`.

- `hasLaunchedBefore` wird **erst im letzten Onboarding-Schritt** („App starten“) gesetzt – das schließt den Cover. Nicht früher setzen (z. B. in `onAppear`), sonst verschwindet das Onboarding sofort.
- Bestandsnutzer (History vorhanden, Key `hasLaunchedBefore` fehlt) bekommen beim ersten Start automatisch `hasLaunchedBefore = true` (`AppSettings.initialHasLaunchedBefore()`), da das Onboarding die Ziele ersetzen würde.

```
OnboardingView (fullScreenCover, 4 Schritte: Willkommen → Ziele → Erinnerungen → Fertig)
ContentView (TabView)
├── TrackerView        – ProgressCardView (Ring), DateSliderView (31 Tage), GoalRowView je Ziel, Streak-Badge
├── AnalyticsView      – Zeitraum-Picker (gespeichert in @AppStorage("analyticsRange"), Default 3 Monate), Kennzahl mit Vorperioden-Vergleich,
│                        Streaks, Trend je Ziel (bei 30 Tagen als Raster Ziel × Tag), Gesamtfortschritt, Wochentage, Top-Kombinationen,
│                        Monatsmatrix in blätterbaren 6-Monats-Fenstern (Charts-Framework)
└── SettingsView       – Ziele (GoalEditorView als Sheet), Theme, Benachrichtigungen, Import/Export, Reset
```

- Der Onboarding-Schritt „Ziele“ startet mit leerer Liste und **ersetzt** `store.goals` komplett durch neue Ziele (neue UUIDs).
- Import/Export-UI ist die private `ImportExportButtons`-Struct in `SettingsView.swift`.
- `TrackerView` hält `today` als State und aktualisiert es bei `NSCalendarDayChanged` und beim Wechsel in den Vordergrund; war „heute“ ausgewählt, springt die Auswahl mit. `DateSliderView` bekommt `today` übergeben.

## Wichtige Konventionen

- **UI-Sprache:** Deutsch (Labels, Fehlermeldungen, Anzeige-Datumsformate mit `de_DE`-Locale).
- **Datumsformat Persistenz:** strikt `yyyy-MM-dd` mit `en_US_POSIX`-Locale über `GoalsStore.dateFormatter` / `GoalsStore.key(for:)` – immer diese Helfer nutzen. Zeitzone = Gerätezeitzone.
- **Animationen:** Spring durchgehend (`response: 0.3, dampingFraction: 0.7`; Ring 0.5/0.7, Onboarding 0.4/0.75).
- **Haptik:** `UIImpactFeedbackGenerator(.medium)` in `GoalsStore.toggle()`.
- `GoalsStore` → `ObservableObject` / `@EnvironmentObject`; `AppSettings` → `@Observable` / `@Environment(AppSettings.self)` (+ `@Bindable` für Bindings) — nicht verwechseln. Previews müssen beide injizieren, wenn die View sie nutzt.
- Alle Views haben `#Preview`-Makros.
- Keine `#available`-Fallbacks nötig: Deployment Target ist 26.2.

## Bekannte Einschränkungen

- **Keine automatisierten Tests** (siehe Build & Run). Änderungen an `GoalsStore` manuell im Simulator prüfen.
- Import im **alten** Format (nur History) ersetzt die Ziele nicht. Hat der Nutzer eigene Ziele (andere UUIDs als `Goal.defaults`), sind die importierten Einträge danach unsichtbar.
- Ziele haben kein Erstellungsdatum: Ein später hinzugefügtes Ziel zählt in den Quoten ab `firstTrackedDay` als verfehlt.
- Löschen eines Ziels entfernt dessen History unwiderruflich (Hinweis steht im Footer der Ziel-Sektion, keine Rückfrage).
- History-Keys basieren auf der Gerätezeitzone; Reisen über Zeitzonen kann Einträge auf Nachbartage verschieben.
- Der Wochentags-Chart stapelt die Quoten aller Ziele; die Y-Achse geht daher von 0 bis Anzahl Ziele.
- Angebrochene Abschnitte am Rand (z. B. die laufende Woche mit erst 1 Tag) werden wie volle gewertet und können in Wochen-/Quartalscharts Ausreißer auf 0 % oder 100 % erzeugen.
- Die Zeitmessungen oben stammen aus einer temporären Messsonde (Launch-Argumente, die automatisch abhaken und die Zeit loggen), die nicht im Code verbleibt. Für neue Messungen: synthetische History erzeugen und über `defaults`/Plist im Simulator einspielen (siehe Build & Run).
