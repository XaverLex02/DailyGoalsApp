import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject private var store: GoalsStore

    // Last 6 months for matrix and overall chart
    private var last6Months: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<6).compactMap { offset in
            cal.date(byAdding: .month, value: -(5 - offset), to: today)
                .flatMap { cal.date(from: cal.dateComponents([.year, .month], from: $0)) }
        }
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yy"
        f.locale = Locale(identifier: "de_DE")
        return f
    }()

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let goal: Goal
        let month: Date
        let rate: Double
    }

    private var chartData: [ChartPoint] {
        store.goals.flatMap { goal in
            store.monthlyRate(for: goal).map { ChartPoint(goal: goal, month: $0.month, rate: $0.rate) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    streakBar
                    trendChart
                    overallChart
                    weekdayChart
                    topCombinationsSection
                    monthlyMatrix
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Analyse")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Streak Bar

    private var streakBar: some View {
        HStack(spacing: 0) {
            ForEach(store.goals) { goal in
                let s = store.streak(for: goal)
                VStack(spacing: 4) {
                    Image(systemName: goal.symbol)
                        .font(.title3)
                        .foregroundStyle(goal.color)
                    HStack(spacing: 2) {
                        if s > 0 {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        Text(s > 0 ? "\(s)" : "–")
                            .font(.caption)
                            .fontWeight(s > 0 ? .semibold : .regular)
                            .foregroundStyle(s > 0 ? .primary : .tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    // MARK: - Trend Chart

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Erfolgsquote pro Monat")
                .font(.headline)

            Group {
                if chartData.isEmpty {
                    Text("Noch keine Daten vorhanden.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    Chart(chartData) { point in
                        LineMark(
                            x: .value("Monat", point.month, unit: .month),
                            y: .value("Quote", point.rate)
                        )
                        .foregroundStyle(by: .value("Ziel", point.goal.name))
                        .symbol(by: .value("Ziel", point.goal.name))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartForegroundStyleScale(
                        domain: store.goals.map(\.name),
                        range: store.goals.map(\.color)
                    )
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) {
                            AxisValueLabel(format: .dateTime.month(.abbreviated).locale(Locale(identifier: "de_DE")))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: [0.0, 0.5, 1.0]) {
                            AxisValueLabel(format: FloatingPointFormatStyle<Double>.Percent())
                        }
                    }
                    .chartYScale(domain: 0...1)
                    .frame(height: 220)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )

            chartLegend
        }
    }

    private var chartLegend: some View {
        FlowLayout(spacing: 8) {
            ForEach(store.goals) { goal in
                HStack(spacing: 6) {
                    Circle()
                        .fill(goal.color)
                        .frame(width: 10, height: 10)
                    Text(goal.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Overall Chart

    private var overallChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gesamtfortschritt")
                .font(.headline)

            let data = store.averageMonthlyRate(months: last6Months)

            Group {
                if data.isEmpty {
                    Text("Noch keine Daten vorhanden.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    Chart(data, id: \.month) { point in
                        LineMark(
                            x: .value("Monat", point.month, unit: .month),
                            y: .value("Quote", point.rate)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.accentColor)
                        .symbol(.circle)
                        AreaMark(
                            x: .value("Monat", point.month, unit: .month),
                            y: .value("Quote", point.rate)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.accentColor.opacity(0.15))
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) {
                            AxisValueLabel(format: .dateTime.month(.abbreviated).locale(Locale(identifier: "de_DE")))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: [0.0, 0.5, 1.0]) {
                            AxisValueLabel(format: FloatingPointFormatStyle<Double>.Percent())
                        }
                    }
                    .chartYScale(domain: 0...1)
                    .frame(height: 160)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }

    // MARK: - Weekday Chart

    private var weekdayChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Wochentage")
                .font(.headline)

            let data = store.weekdayAverages()
            let hasData = data.contains { $0.average > 0 }

            Group {
                if !hasData {
                    Text("Noch keine Daten vorhanden.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    Chart(data) { point in
                        BarMark(
                            x: .value("Tag", point.weekdayLabel),
                            y: .value("Ø", point.average)
                        )
                        .foregroundStyle(by: .value("Ziel", point.goal.name))
                    }
                    .chartForegroundStyleScale(
                        domain: store.goals.map(\.name),
                        range: store.goals.map(\.color)
                    )
                    .chartXAxis {
                        AxisMarks { AxisValueLabel() }
                    }
                    .chartYAxis {
                        AxisMarks(values: [0, 1, 2, 3, 4, 5]) {
                            AxisValueLabel()
                        }
                    }
                    .chartYScale(domain: 0...5)
                    .frame(height: 180)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }

    // MARK: - Top Combinations

    private var topCombinationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top-Kombinationen")
                .font(.headline)

            let pairs = store.topPairs()

            VStack(spacing: 0) {
                if pairs.isEmpty {
                    Text("Noch nicht genug Daten.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(Array(pairs.enumerated()), id: \.element.id) { index, pair in
                        HStack(spacing: 8) {
                            Label(pair.goal1.name, systemImage: pair.goal1.symbol)
                                .foregroundStyle(pair.goal1.color)
                                .font(.subheadline)
                            Text("+")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                            Label(pair.goal2.name, systemImage: pair.goal2.symbol)
                                .foregroundStyle(pair.goal2.color)
                                .font(.subheadline)
                            Spacer()
                            Text("\(pair.count) Tage")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        if index < pairs.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }

    // MARK: - Monthly Matrix

    private var monthlyMatrix: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Monatsübersicht")
                .font(.headline)

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("")
                        .frame(width: 90, alignment: .leading)
                    ForEach(last6Months, id: \.self) { month in
                        Text(Self.monthFormatter.string(from: month))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)

                ForEach(store.goals) { goal in
                    HStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: goal.symbol)
                                .font(.caption)
                                .foregroundStyle(goal.color)
                            Text(goal.name)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(width: 90, alignment: .leading)

                        ForEach(last6Months, id: \.self) { month in
                            MatrixCell(rate: store.monthlyRate(for: goal, month: month))
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }
}

// MARK: - Sub-views

private struct MatrixCell: View {
    let rate: Double?

    private var cellColor: Color {
        guard let rate else { return Color(uiColor: .quaternarySystemFill) }
        switch rate {
        case 0.8...: return .green.opacity(0.7)
        case 0.5...: return .orange.opacity(0.7)
        default:     return .red.opacity(0.5)
        }
    }

    private var label: String {
        guard let rate else { return "–" }
        return "\(Int(rate * 100))%"
    }

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(rate == nil ? .tertiary : .primary)
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(cellColor)
            )
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width + (rowWidth > 0 ? spacing : 0) > maxWidth {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(GoalsStore())
}
