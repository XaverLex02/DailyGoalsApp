import SwiftUI

struct TrackerView: View {
    @EnvironmentObject private var store: GoalsStore
    @State private var today: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Progress Ring
                    ProgressCardView(
                        completedCount: store.completionCount(for: selectedDate),
                        total: store.goals.count
                    )
                    .frame(height: 200)
                    .padding(.horizontal)

                    // Date Slider
                    DateSliderView(selectedDate: $selectedDate, today: today)

                    // Goal Rows
                    VStack(spacing: 10) {
                        ForEach(store.goals) { goal in
                            GoalRowView(
                                goal: goal,
                                isCompleted: store.isCompleted(goal, for: selectedDate)
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    store.toggle(goal, for: selectedDate)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Tages-Ziele")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    streakBadge
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                // Kommt nicht zwingend auf dem Main Thread an
                Task { @MainActor in refreshToday() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                refreshToday()
            }
        }
    }

    /// Bei Tageswechsel (App offen oder aus dem Hintergrund) auf den neuen Tag wechseln,
    /// sofern bisher „heute“ ausgewählt war.
    private func refreshToday() {
        let newToday = Calendar.current.startOfDay(for: Date())
        guard newToday != today else { return }
        if Calendar.current.isDate(selectedDate, inSameDayAs: today) {
            selectedDate = newToday
        }
        today = newToday
    }

    @ViewBuilder
    private var streakBadge: some View {
        if store.currentStreak > 0 {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("\(store.currentStreak)")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
    }
}

#Preview {
    TrackerView()
        .environmentObject(GoalsStore())
}
