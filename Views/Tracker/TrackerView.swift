import SwiftUI

struct TrackerView: View {
    @EnvironmentObject private var store: GoalsStore
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
                    DateSliderView(selectedDate: $selectedDate)

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
        }
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
