import Combine
import SwiftUI

@main
struct DailyGoalsApp: App {
    @StateObject private var store = GoalsStore()
    @State private var settings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environment(settings)
                .preferredColorScheme(settings.preferredColorScheme)
                // Erinnerungen enthalten die offenen Ziele → bei jeder Änderung und beim Öffnen neu planen
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .active { store.rescheduleReminders(settings: settings) }
                }
                .onReceive(store.objectWillChange) { _ in
                    // objectWillChange kommt vor der Änderung → im nächsten Durchlauf planen
                    DispatchQueue.main.async { store.rescheduleReminders(settings: settings) }
                }
                .fullScreenCover(isPresented: Binding(
                    get: { !settings.hasLaunchedBefore },
                    set: { _ in }
                )) {
                    OnboardingView()
                        .environmentObject(store)
                        .environment(settings)
                }
        }
    }
}
