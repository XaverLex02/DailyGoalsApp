import SwiftUI

@main
struct DailyGoalsApp: App {
    @StateObject private var store = GoalStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                CalendarView(store: store)
                    .tabItem { Label("Kalender", systemImage: "calendar") }
                StatisticsView(store: store)
                    .tabItem { Label("Statistik", systemImage: "chart.bar") }
            }
        }
    }
}
