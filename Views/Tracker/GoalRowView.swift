import SwiftUI

struct GoalRowView: View {
    let goal: Goal
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: goal.symbol)
                    .font(.title2)
                    .foregroundStyle(goal.color)
                    .frame(width: 28)

                Text(goal.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                toggleIcon
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var toggleIcon: some View {
        let image = Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundStyle(isCompleted ? goal.color : Color.secondary)

        if #available(iOS 17, *) {
            image.contentTransition(.symbolEffect(.replace))
        } else {
            image.animation(.easeInOut(duration: 0.2), value: isCompleted)
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        GoalRowView(goal: Goal.defaults[0], isCompleted: true, action: {})
        GoalRowView(goal: Goal.defaults[1], isCompleted: false, action: {})
    }
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
