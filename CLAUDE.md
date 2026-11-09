# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Dieses Projekt ist eine native iOS-App und wird ausschließlich über Xcode gebaut:

- **Bauen:** `xcodebuild -project DailyGoals.xcodeproj -scheme DailyGoals -destination 'platform=iOS Simulator,name=iPhone 16'`
- **Tests ausführen:** `xcodebuild test -project DailyGoals.xcodeproj -scheme DailyGoals -destination 'platform=iOS Simulator,name=iPhone 16'`
- **Einzelnen Test ausführen:** `-only-testing:DailyGoalsTests/TestClassName/testMethodName` an den Test-Befehl anhängen

Normalerweise wird die App direkt über Xcode gebaut und auf dem Simulator gestartet. Es gibt keine Makefile, kein Swift Package Manager Setup und keine externen Build-Skripte.

## Architektur

**Pattern:** MVVM mit SwiftUI; zwei verschiedene Observable-Mechanismen parallel im Einsatz

### Datenschicht

`GoalsStore` (`Views/Tracker/GoalsStore.swift`) ist die einzige Datenquelle – eine `@MainActor`-Klasse (`ObservableObject`), die als `@StateObject` in `DailyGoalsApp` erstellt und per `.environmentObject()` weitergegeben wird.

- **Persistenz:** `@AppStorage("goalsHistory")` und `@AppStorage("goals")` speichern JSON in UserDefaults
- **Datenformat History:** `[String: [String: Bool]]` — äußerer Key ist Datum (`yyyy-MM-dd`), innerer Key ist `goal.id.uuidString`, Wert ist Abschluss-Status
- **Datenformat Goals:** `[Goal]` — dynamische Liste mit max. 5, min. 1 Ziel
- Manuelle Änderungsbenachrichtigung über `objectWillChange.send()` nötig
- Migration von alten `GoalType.rawValue`-Keys auf UUIDs erfolgt in `migrateIfNeeded()` via `Goal.migrationMap`

`AppSettings` (`Models/AppSettings.swift`) verwaltet Theme und Benachrichtigungseinstellungen – eine `@Observable`-Klasse (Swift Observation Framework), die per `.environment()` (nicht `.environmentObject()`) weitergegeben wird.

### Datenmodelle

- `Goal` (`Models/Goal.swift`): `Identifiable & Codable & Equatable`-Struct mit `id: UUID`, `name`, `colorHex`, `symbol`. Enthält fünf Standardziele in `Goal.defaults` mit fest codierten UUIDs für Migration.
- `AppSettings` (`Models/AppSettings.swift`): `@Observable`-Klasse für `colorScheme`, `notificationsEnabled`, `notificationHour/Minute`
- `NotificationManager` (`Models/NotificationManager.swift`): Verwaltet lokale Push-Benachrichtigungen

### Views

```
ContentView (TabView)
├── TrackerView        – Tagesansicht mit Datumswähler und Ziel-Toggles
├── AnalyticsView      – Statistiken: Streak-Karten, Liniendiagramm, Monatsmatrix
└── SettingsView       – Einstellungen, Ziel-Editor, Import/Export
```

- `TrackerView` enthält `ProgressCardView` (kreisförmige Fortschrittsanzeige), `DateSliderView` (horizontaler Datumskarussell, 31 Tage) und `GoalRowView` pro Ziel
- `AnalyticsView` nutzt das SwiftUI **Charts**-Framework
- `SettingsView` enthält `GoalEditorView` (Ziele hinzufügen/bearbeiten/löschen) und `ImportExportView` als Unteransichten
- iOS 17+ nutzt `.symbolEffect` für Animationen; für ältere Versionen gibt es einen Fallback

## Wichtige Konventionen

- **Sprache der UI:** Deutsch (alle Labels, Fehlermeldungen, Datumsformate mit `de_DE`-Locale)
- **Animationen:** Spring-Physik durchgehend (`response: 0.3, dampingFraction: 0.7`)
- **Haptic Feedback:** `UIImpactFeedbackGenerator` beim Umschalten von Zielen in `GoalsStore.toggle()`
- **Datumsformat:** Strikt `yyyy-MM-dd` mit POSIX-Locale für Persistenz; `de_DE`-Locale nur für Anzeige
- `GoalsStore` nutzt `ObservableObject` / `@EnvironmentObject`; `AppSettings` nutzt `@Observable` / `@Environment` — nicht verwechseln
- Alle Views haben `#Preview`-Makros für das Xcode Canvas
