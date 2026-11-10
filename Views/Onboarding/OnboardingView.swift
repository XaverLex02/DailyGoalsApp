import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @EnvironmentObject private var store: GoalsStore
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            progressDots
                .padding(.vertical, 16)

            ZStack {
                switch step {
                case 0:
                    WelcomeStep(onNext: nextStep)
                case 1:
                    GoalsStep(onNext: nextStep)
                case 2:
                    NotificationsStep(onNext: nextStep)
                default:
                    // Erst hier als erledigt markieren: Das Setzen schließt den fullScreenCover.
                    // Würde es früher passieren (z. B. onAppear), verschwände das Onboarding sofort.
                    FinishStep(onFinish: { settings.hasLaunchedBefore = true })
                }
            }
            .id(step)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: step)
        }
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: i == step ? 20 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: step)
    }

    private func nextStep() {
        step += 1
    }
}

// MARK: - Schritt 1: Willkommen

private struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 32)

            VStack(spacing: 10) {
                Text("Willkommen bei")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("DailyGoals")
                    .font(.largeTitle.bold())
            }
            .padding(.bottom, 20)

            Text("Richte jetzt deine persönlichen Tagesziele ein und bleib täglich auf Kurs.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()

            Button(action: onNext) {
                Text("Los geht's")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Schritt 2: Ziele

private enum GoalEditorMode: Identifiable {
    case new
    case edit(Goal)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let g): return g.id.uuidString
        }
    }
}

private struct GoalsStep: View {
    @EnvironmentObject private var store: GoalsStore
    let onNext: () -> Void

    @State private var pendingGoals: [Goal] = []
    @State private var editorMode: GoalEditorMode? = nil

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: "star.fill")
                        .font(.title)
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.bottom, 4)

                Text("Deine Ziele")
                    .font(.largeTitle.bold())

                Text("Erstelle die Ziele, die du täglich verfolgen möchtest.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 12)
            .padding(.bottom, 8)

            if pendingGoals.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Noch keine Ziele hinzugefügt")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(pendingGoals) { goal in
                        HStack(spacing: 14) {
                            Image(systemName: goal.symbol)
                                .font(.title3)
                                .foregroundStyle(goal.color)
                                .frame(width: 28)
                            Text(goal.name)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editorMode = .edit(goal)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                pendingGoals.removeAll { $0.id == goal.id }
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }

            VStack(spacing: 12) {
                if pendingGoals.count < 5 {
                    Button {
                        editorMode = .new
                    } label: {
                        Label("Ziel hinzufügen", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                Button(action: proceed) {
                    Text("Weiter")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(pendingGoals.isEmpty ? Color.secondary.opacity(0.25) : Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(pendingGoals.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .sheet(item: $editorMode) { mode in
            switch mode {
            case .new:
                GoalEditorView { newGoal in
                    pendingGoals.append(newGoal)
                }
            case .edit(let goal):
                GoalEditorView(goal: goal) { updated in
                    if let idx = pendingGoals.firstIndex(where: { $0.id == updated.id }) {
                        pendingGoals[idx] = updated
                    }
                }
            }
        }
    }

    private func proceed() {
        store.goals = pendingGoals
        onNext()
    }
}

// MARK: - Schritt 3: Benachrichtigungen

private struct NotificationsStep: View {
    @Environment(AppSettings.self) private var settings
    @EnvironmentObject private var store: GoalsStore
    let onNext: () -> Void

    var body: some View {
        @Bindable var settings = settings

        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "bell.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
            }
            .padding(.bottom, 24)

            VStack(spacing: 10) {
                Text("Erinnerungen")
                    .font(.largeTitle.bold())
                Text("Lass dich täglich erinnern, deine Ziele zu verfolgen.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 36)

            VStack(spacing: 0) {
                Toggle("Tägliche Erinnerung", isOn: $settings.notificationsEnabled)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                if settings.notificationsEnabled {
                    Divider()
                        .padding(.leading, 20)
                    DatePicker(
                        "Uhrzeit",
                        selection: $settings.notificationDate,
                        displayedComponents: .hourAndMinute
                    )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: settings.notificationsEnabled)

            Spacer()
            Spacer()

            Button(action: onNext) {
                Text("Weiter")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onChange(of: settings.notificationDate) { _, _ in
            store.rescheduleReminders(settings: settings)
        }
        .onChange(of: settings.notificationsEnabled) { _, enabled in
            guard enabled else {
                store.rescheduleReminders(settings: settings)
                return
            }
            Task {
                let granted = await NotificationManager.requestPermission()
                if granted {
                    store.rescheduleReminders(settings: settings)
                } else {
                    settings.notificationsEnabled = false
                }
            }
        }
    }
}

// MARK: - Schritt 4: Fertig

private struct FinishStep: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
            }
            .padding(.bottom, 32)

            VStack(spacing: 10) {
                Text("Alles bereit!")
                    .font(.largeTitle.bold())
                Text("Du kannst jetzt mit dem Verfolgen deiner Ziele beginnen.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
            }

            Spacer()
            Spacer()

            Button(action: onFinish) {
                Text("App starten")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environmentObject(GoalsStore())
        .environment(AppSettings())
}
