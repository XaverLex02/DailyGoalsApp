import SwiftUI

struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (Goal) -> Void
    private let isNew: Bool

    @State private var name: String
    @State private var color: Color
    @State private var symbol: String
    @State private var description: String

    private let goalId: UUID

    // Für neues Ziel
    init(onSave: @escaping (Goal) -> Void) {
        self.onSave = onSave
        self.isNew = true
        self.goalId = UUID()
        _name = State(initialValue: "")
        _color = State(initialValue: .blue)
        _symbol = State(initialValue: "star.fill")
        _description = State(initialValue: "")
    }

    // Für bestehendes Ziel bearbeiten
    init(goal: Goal, onSave: @escaping (Goal) -> Void) {
        self.onSave = onSave
        self.isNew = false
        self.goalId = goal.id
        _name = State(initialValue: goal.name)
        _color = State(initialValue: goal.color)
        _symbol = State(initialValue: goal.symbol)
        _description = State(initialValue: goal.description ?? "")
    }

    private static let symbols: [String] = [
        "book.fill", "graduationcap.fill", "pencil", "doc.fill", "note.text",
        "dumbbell.fill", "figure.run", "figure.walk", "bicycle", "flame.fill",
        "heart.fill", "brain.head.profile", "lungs.fill", "fork.knife",
        "bed.double.fill", "sunrise.fill", "moon.fill", "alarm.fill",
        "play.rectangle.fill", "tv.fill", "gamecontroller.fill", "headphones",
        "music.note", "camera.fill", "paintbrush.fill", "leaf.fill",
        "drop.fill", "cup.and.saucer.fill", "cart.fill", "house.fill",
        "star.fill", "trophy.fill", "medal.fill", "checkmark.seal.fill",
        "lightbulb.fill", "wrench.fill", "chart.bar.fill", "globe",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Zielname", text: $name)
                }

                Section("Beschreibung") {
                    TextField("Optional…", text: $description, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Farbe") {
                    ColorPicker("Farbe wählen", selection: $color, supportsOpacity: false)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(Self.symbols, id: \.self) { sym in
                            Button {
                                symbol = sym
                            } label: {
                                Image(systemName: sym)
                                    .font(.title2)
                                    .foregroundStyle(sym == symbol ? color : .secondary)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(sym == symbol
                                                  ? color.opacity(0.15)
                                                  : Color(uiColor: .tertiarySystemFill))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(sym == symbol ? color : .clear, lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Vorschau") {
                    HStack(spacing: 14) {
                        Image(systemName: symbol)
                            .font(.title2)
                            .foregroundStyle(color)
                            .frame(width: 28)
                        Text(name.isEmpty ? "Zielname" : name)
                            .foregroundStyle(name.isEmpty ? .secondary : .primary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isNew ? "Neues Ziel" : "Ziel bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let hexColor = UIColor(color).toHex() ?? "#3B82F6"
                        let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(Goal(id: goalId, name: name, colorHex: hexColor, symbol: symbol, description: desc.isEmpty ? nil : desc))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

private extension UIColor {
    func toHex() -> String? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

#Preview {
    GoalEditorView { _ in }
}
