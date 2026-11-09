import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TrackerView()
                .tabItem {
                    Label("Tracker", systemImage: "checkmark.circle.fill")
                }
            AnalyticsView()
                .tabItem {
                    Label("Analyse", systemImage: "chart.bar.fill")
                }
            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GoalsStore())
        .environment(AppSettings())
}
