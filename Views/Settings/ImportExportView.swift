import SwiftUI

struct ImportExportView: View {
    @EnvironmentObject private var store: GoalsStore

    @State private var showCopied = false
    @State private var showImportConfirm = false
    @State private var importError: String?
    @State private var showImportSuccess = false
    @State private var clipboardContent: String = ""

    var body: some View {
        NavigationStack {
            List {
                exportSection
                importSection
                infoSection
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Import / Export")
            .navigationBarTitleDisplayMode(.large)
            .alert("Import erfolgreich", isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Die Daten wurden importiert.")
            }
            .alert("Fehler beim Import", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "")
            }
            .alert("Daten importieren?", isPresented: $showImportConfirm) {
                Button("Importieren", role: .destructive) { performImport() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Alle vorhandenen Daten werden überschrieben.")
            }
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        Section {
            Button {
                exportToClipboard()
            } label: {
                HStack {
                    Label("In Zwischenablage kopieren", systemImage: "doc.on.clipboard")
                    Spacer()
                    if showCopied {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .foregroundStyle(.primary)
        } header: {
            Text("Export")
        } footer: {
            Text("Exportiert alle Einträge als JSON in die Zwischenablage.")
        }
    }

    private func exportToClipboard() {
        guard let json = store.exportJSON() else { return }
        UIPasteboard.general.string = json
        withAnimation(.spring()) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopied = false }
        }
    }

    // MARK: - Import

    private var importSection: some View {
        Section {
            Button {
                let content = UIPasteboard.general.string ?? ""
                clipboardContent = content
                guard !content.isEmpty else {
                    importError = "Die Zwischenablage ist leer."
                    return
                }
                showImportConfirm = true
            } label: {
                Label("Aus Zwischenablage importieren", systemImage: "doc.badge.plus")
            }
            .foregroundStyle(.primary)
        } header: {
            Text("Import")
        } footer: {
            Text("Liest JSON-Daten aus der Zwischenablage. Alle vorhandenen Einträge werden ersetzt.")
        }
    }

    private func performImport() {
        do {
            try store.importJSON(clipboardContent)
            showImportSuccess = true
        } catch {
            importError = error.localizedDescription
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        Section("Datenformat") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Das JSON-Format ist ein Dictionary mit Datumsstrings (yyyy-MM-dd) als Schlüssel, die auf ein Dictionary aus Ziel-IDs und Boolean-Werten abgebildet werden.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Beispiel:")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .padding(.top, 4)

                Text("""
{
  "2026-03-25": {
    "lesen": true,
    "sport": false
  }
}
""")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    ImportExportView()
        .environmentObject(GoalsStore())
}
