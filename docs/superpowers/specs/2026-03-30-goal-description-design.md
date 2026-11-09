# Design: Ziel-Beschreibung

**Datum:** 2026-03-30

## Zusammenfassung

Nutzende sollen beim Erstellen oder Bearbeiten eines Ziels eine optionale Beschreibung eingeben können. Die Beschreibung dient als persönliche Notiz und wird ausschließlich im Editor angezeigt – nicht in der Tagesansicht oder Analytics.

## Scope

- **In scope:** Beschreibungsfeld in `GoalEditorView`, Persistenz im `Goal`-Modell
- **Out of scope:** Anzeige in `TrackerView`, `AnalyticsView` oder anderen Views

## Datenmodell

`Goal.swift` erhält ein neues optionales Feld:

```swift
var description: String?
```

`String?` wird gewählt, damit bestehende gespeicherte Daten (ohne `description`-Schlüssel) korrekt als `nil` dekodiert werden – ohne eigenen `init(from:)` Decoder.

## UI

In `GoalEditorView` wird nach dem „Name"-Abschnitt ein neuer Abschnitt eingefügt:

```
Section("Beschreibung") {
    TextField("Optional...", text: $description, axis: .vertical)
        .lineLimit(3, reservesSpace: true)
}
```

Intern wird ein `@State private var description: String` (leerer String) verwendet. Beim Speichern wird ein leerer String in `nil` umgewandelt.

## Betroffene Dateien

| Datei | Änderung |
|---|---|
| `Models/Goal.swift` | `var description: String?` hinzufügen |
| `Views/Settings/GoalEditorView.swift` | State, TextField-Sektion, Speicher-Logik |

Keine weiteren Dateien werden geändert.
