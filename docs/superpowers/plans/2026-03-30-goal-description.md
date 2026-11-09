# Goal-Beschreibung Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Optionales Beschreibungsfeld zu `Goal` hinzufügen, das im `GoalEditorView` eingegeben werden kann.

**Architecture:** `Goal.description: String?` als neues optionales Feld – `nil` wenn leer. `GoalEditorView` bekommt eine neue State-Variable und ein mehrzeiliges TextField. Keine anderen Views werden geändert.

**Tech Stack:** Swift, SwiftUI, iOS, Codable/UserDefaults

---

### Task 1: `Goal`-Modell erweitern

**Files:**
- Modify: `Models/Goal.swift`

- [ ] **Schritt 1: `description`-Feld hinzufügen**

In `Models/Goal.swift` das Struct um das neue Feld ergänzen:

```swift
struct Goal: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var colorHex: String
    var symbol: String
    var description: String?   // NEU
    // ...
}
```

Das Feld nach `symbol` einfügen. Da `String?` optional ist, dekodiert `Codable` fehlende Schlüssel automatisch als `nil` – bestehende gespeicherte Daten bleiben kompatibel.

- [ ] **Schritt 2: App bauen und prüfen**

```
xcodebuild -project DailyGoals.xcodeproj -scheme DailyGoals \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Erwartetes Ergebnis: `BUILD SUCCEEDED`. Falls Compiler-Fehler auftreten, liegt es daran, dass anderswo `Goal(id:name:colorHex:symbol:)` aufgerufen wird – dann alle Aufrufe mit `description: nil` ergänzen.

---

### Task 2: `GoalEditorView` anpassen

**Files:**
- Modify: `Views/Settings/GoalEditorView.swift`

- [ ] **Schritt 1: State-Variable ergänzen**

Nach den bestehenden `@State`-Variablen einfügen:

```swift
@State private var description: String
```

- [ ] **Schritt 2: `init` für neues Ziel anpassen**

```swift
init(onSave: @escaping (Goal) -> Void) {
    self.onSave = onSave
    self.isNew = true
    self.goalId = UUID()
    _name = State(initialValue: "")
    _color = State(initialValue: .blue)
    _symbol = State(initialValue: "star.fill")
    _description = State(initialValue: "")   // NEU
}
```

- [ ] **Schritt 3: `init` für bestehendes Ziel anpassen**

```swift
init(goal: Goal, onSave: @escaping (Goal) -> Void) {
    self.onSave = onSave
    self.isNew = false
    self.goalId = goal.id
    _name = State(initialValue: goal.name)
    _color = State(initialValue: goal.color)
    _symbol = State(initialValue: goal.symbol)
    _description = State(initialValue: goal.description ?? "")   // NEU
}
```

- [ ] **Schritt 4: Beschreibungs-Sektion in `body` einfügen**

Direkt nach `Section("Name") { ... }` einfügen:

```swift
Section("Beschreibung") {
    TextField("Optional…", text: $description, axis: .vertical)
        .lineLimit(3, reservesSpace: true)
}
```

- [ ] **Schritt 5: Speicher-Logik aktualisieren**

Den `onSave`-Aufruf im Toolbar-Button anpassen:

```swift
Button("Speichern") {
    let hexColor = UIColor(color).toHex() ?? "#3B82F6"
    let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
    onSave(Goal(
        id: goalId,
        name: name,
        colorHex: hexColor,
        symbol: symbol,
        description: desc.isEmpty ? nil : desc   // NEU
    ))
    dismiss()
}
```

- [ ] **Schritt 6: App bauen und manuell testen**

```
xcodebuild -project DailyGoals.xcodeproj -scheme DailyGoals \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Erwartetes Ergebnis: `BUILD SUCCEEDED`.

Manuelle Checks im Simulator:
- Neues Ziel anlegen → Beschreibungsfeld erscheint unter „Name"
- Beschreibung eingeben, speichern, Ziel erneut öffnen → Text ist noch da
- Beschreibung leer lassen → funktioniert ohne Fehler
- Bestehendes Ziel (ohne Beschreibung) öffnen → Feld leer, kein Absturz
