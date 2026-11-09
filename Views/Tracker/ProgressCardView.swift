import SwiftUI

struct ProgressCardView: View {
    let completedCount: Int
    let total: Int

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(completedCount) / CGFloat(total)
    }

    private var ringColor: Color {
        switch progress {
        case 1.0:        return .green
        case 0.8...:     return Color(hue: 0.27, saturation: 0.7, brightness: 0.8)  // Gelbgrün
        case 0.5...:     return .orange
        default:         return .red
        }
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(lineWidth: 14)
                .foregroundStyle(.secondary.opacity(0.2))

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .foregroundStyle(ringColor)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: completedCount)

            // Center label
            VStack(spacing: 2) {
                Text("\(completedCount)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("von \(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    ProgressCardView(completedCount: 3, total: 5)
        .frame(width: 200, height: 200)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
