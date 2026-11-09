import SwiftUI

@main
struct DailyGoalsApp: App {
    @StateObject private var store = GoalsStore()
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environment(settings)
                .preferredColorScheme(settings.preferredColorScheme)
                .task {
                    if settings.notificationsEnabled {
                        NotificationManager.schedule(
                            hour: settings.notificationHour,
                            minute: settings.notificationMinute
                        )
                    }
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
