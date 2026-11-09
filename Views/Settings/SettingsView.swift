import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: GoalsStore
    @Environment(AppSettings.self) private var settings

    @State private var editingGoal: Goal?
    @State private var showAddGoal = false
    @State private var showResetConfirm = false
    @State private var showPermissionDeniedAlert = false

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                goalsSection
                appearanceSection(settings: $settings)
                notificationsSection(settings: $settings)
                dataSection
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $editingGoal) { goal in
                GoalEditorView(goal: goal) { updated in
                    store.updateGoal(updated)
                }
            }
            .sheet(isPresented: $showAddGoal) {
                GoalEditorView { newGoal in
                    store.addGoal(newGoal)
                }
            }
            .alert("Benachrichtigungen nicht erlaubt", isPresented: $showPermissionDeniedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Bitte erlaube Benachrichtigungen in den Systemeinstellungen.")
            }
            .alert("App zurücksetzen?", isPresented: $showResetConfirm) {
                Button("Zurücksetzen", role: .destructive) {
                    store.resetApp(settings: settings)
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Alle Einträge werden gelöscht und die ursprünglichen Ziele wiederhergestellt.")
            }
        }
    }

    // MARK: - Ziele

    private var goalsSection: some View {
        Section {
            ForEach(store.goals) { goal in
                Button {
                    editingGoal = goal
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: goal.symbol)
                            .font(.body)
                            .foregroundStyle(goal.color)
                            .frame(width: 24)
                        Text(goal.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let goal = store.goals[index]
                    guard store.goals.count > 1 else { return }
                    store.removeGoal(goal)
                }
            }

            if store.goals.count < 5 {
                Button {
                    showAddGoal = true
                } label: {
                    Label("Ziel hinzufügen", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
        } header: {
            Text("Ziele")
        } footer: {
            Text("Mindestens 1, maximal 5 Ziele.")
        }
    }

    // MARK: - Erscheinungsbild

    private func appearanceSection(settings: Bindable<AppSettings>) -> some View {
        Section("Erscheinungsbild") {
            Picker("Theme", selection: settings.colorScheme) {
                Text("System").tag("system")
                Text("Hell").tag("light")
                Text("Dunkel").tag("dark")
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Benachrichtigungen

    private func notificationsSection(settings: Bindable<AppSettings>) -> some View {
        Section("Benachrichtigungen") {
            Toggle("Tägliche Erinnerung", isOn: settings.notificationsEnabled)
                .onChange(of: settings.wrappedValue.notificationsEnabled) { _, enabled in
                    if enabled {
                        Task {
                            let granted = await NotificationManager.requestPermission()
                            if granted {
                                NotificationManager.schedule(
                                    hour: settings.wrappedValue.notificationHour,
                                    minute: settings.wrappedValue.notificationMinute
                                )
                            } else {
                                settings.wrappedValue.notificationsEnabled = false
                                showPermissionDeniedAlert = true
                            }
                        }
                    } else {
                        NotificationManager.cancel()
                    }
                }

            if settings.wrappedValue.notificationsEnabled {
                DatePicker("Uhrzeit", selection: settings.notificationDate, displayedComponents: .hourAndMinute)
                    .onChange(of: settings.wrappedValue.notificationDate) { _, _ in
                        NotificationManager.schedule(
                            hour: settings.wrappedValue.notificationHour,
                            minute: settings.wrappedValue.notificationMinute
                        )
                    }
            }
        }
    }

    // MARK: - Daten

    private var dataSection: some View {
        Section("Daten") {
            ImportExportButtons()

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("App zurücksetzen", systemImage: "arrow.counterclockwise")
            }
        }
    }
}

// MARK: - Import/Export Buttons

private struct ImportExportButtons: View {
    @EnvironmentObject private var store: GoalsStore

    @State private var showCopied = false
    @State private var showImportConfirm = false
    @State private var importError: String?
    @State private var showImportSuccess = false
    @State private var clipboardContent: String = ""

    var body: some View {
        Button {
            exportToClipboard()
        } label: {
            HStack {
                Label("Exportieren", systemImage: "doc.on.clipboard")
                Spacer()
                if showCopied {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .foregroundStyle(.primary)

        Button {
            let content = UIPasteboard.general.string ?? ""
            clipboardContent = content
            guard !content.isEmpty else {
                importError = "Die Zwischenablage ist leer."
                return
            }
            showImportConfirm = true
        } label: {
            Label("Importieren", systemImage: "doc.badge.plus")
        }
        .foregroundStyle(.primary)
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

    private func exportToClipboard() {
        guard let json = store.exportJSON() else { return }
        UIPasteboard.general.string = json
        withAnimation(.spring()) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopied = false }
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
}

#Preview {
    SettingsView()
        .environmentObject(GoalsStore())
        .environment(AppSettings())
}
