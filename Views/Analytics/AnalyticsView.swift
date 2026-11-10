import Combine
import SwiftUI
import Charts

/// Analyse-Tab.
///
/// Performance: Der TabView hält diese View nach dem ersten Öffnen am Leben, und sie beobachtet den
/// `GoalsStore` → ihr `body` läuft bei jedem Abhaken im Tracker. Deshalb rechnet sie nur, solange sie
/// sichtbar ist, und reicht die Ergebnisse an die `Equatable`-View `AnalyticsContent` weiter, die
/// SwiftUI bei unveränderten Daten nicht neu auswertet.
struct AnalyticsView: View {
    @EnvironmentObject private var store: GoalsStore

    @AppStorage("analyticsRange") private var rangeRaw: String = AnalyticsRange.months3.rawValue
    /// 0 = aktuelles 6-Monats-Fenster der Matrix, 1 = sechs Monate davor, …
    @State private var matrixPage = 0
    @State private var isVisible = false
    @State private var snapshot: AnalyticsSnapshot?
    @State private var matrix: MonthMatrix?

    private var range: AnalyticsRange { AnalyticsRange(rawValue: rangeRaw) ?? .months3 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Zeitraum", selection: $rangeRaw) {
                        ForEach(AnalyticsRange.allCases) { r in
                            Text(r.label).tag(r.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    AnalyticsContent(snapshot: snapshot, matrix: matrix, matrixPage: $matrixPage)
                        .equatable()
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Analyse")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            isVisible = true
            refresh()
        }
        .onDisappear { isVisible = false }
        .onReceive(store.objectWillChange) { _ in
            // objectWillChange kommt *vor* der Änderung → im nächsten Durchlauf neu laden
            guard isVisible else { return }
            DispatchQueue.main.async { refresh() }
        }
        .onChange(of: rangeRaw) { _, _ in refresh() }
        .onChange(of: matrixPage) { _, _ in refresh() }
    }

    private func refresh() {
        snapshot = store.analyticsSnapshot(range: range)
        matrix = MonthMatrix(store: store, page: matrixPage)
    }
}

// MARK: - Monatsmatrix-Daten

struct MonthMatrix: Equatable {
    struct Row: Equatable, Identifiable {
        let goal: Goal
        let rates: [Double?]
        var id: UUID { goal.id }
    }

    let months: [Date]
    let rows: [Row]
    let canGoBack: Bool
    let canGoForward: Bool

    @MainActor
    init?(store: GoalsStore, page: Int) {
        let cal = Calendar.current
        guard let first = store.firstTrackedDay,
              let firstMonth = cal.date(from: cal.dateComponents([.year, .month], from: first)),
              let currentMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())),
              let lastMonth = cal.date(byAdding: .month, value: -6 * page, to: currentMonth) else { return nil }
        let months = (0..<6).compactMap { cal.date(byAdding: .month, value: $0 - 5, to: lastMonth) }
        self.months = months
        self.rows = store.goals.map { goal in
            Row(goal: goal, rates: months.map { store.monthlyRate(for: goal, month: $0) })
        }
        self.canGoBack = (months.first ?? firstMonth) > firstMonth
        self.canGoForward = page > 0
    }
}

// MARK: - Inhalt

private struct AnalyticsContent: View, Equatable {
    let snapshot: AnalyticsSnapshot?
    let matrix: MonthMatrix?
    @Binding var matrixPage: Int

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.snapshot == rhs.snapshot && lhs.matrix == rhs.matrix
    }

    var body: some View {
        if let snapshot {
            VStack(spacing: 20) {
                SummaryCard(snapshot: snapshot)
                StreakBar(snapshot: snapshot)
                TrendChart(snapshot: snapshot)
                OverallChart(snapshot: snapshot)
                WeekdayChart(snapshot: snapshot)
                TopPairsSection(snapshot: snapshot)
                if let matrix {
                    MatrixSection(matrix: matrix, page: $matrixPage)
                }
            }
        } else {
            Text("Noch keine Daten vorhanden.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 180)
                .card()
        }
    }
}

// MARK: - Formatierung

private enum AnalyticsFormat {
    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale(identifier: "de_DE")
        return f
    }

    static let dayMonth = formatter("d. MMM")
    static let dayMonthYear = formatter("d. MMM yyyy")
    static let monthYear = formatter("MMM yy")

    static func axisLabel(_ date: Date, granularity: AnalyticsGranularity) -> String {
        switch granularity {
        case .day, .week:
            return dayMonth.string(from: date)
        case .month:
            return monthYear.string(from: date)
        case .quarter:
            let cal = Calendar.current
            let q = (cal.component(.month, from: date) - 1) / 3 + 1
            return "Q\(q) \(cal.component(.year, from: date) % 100)"
        }
    }

    static func bucketTitle(_ granularity: AnalyticsGranularity) -> String {
        switch granularity {
        case .day:     return "Erledigt pro Tag"
        case .week:    return "Erfolgsquote pro Woche"
        case .month:   return "Erfolgsquote pro Monat"
        case .quarter: return "Erfolgsquote pro Quartal"
        }
    }

    /// Höchstens ~5 Achsenbeschriftungen, gleichmäßig über die Abschnitte verteilt
    static func ticks(_ buckets: [AnalyticsSnapshot.Bucket]) -> [Date] {
        guard !buckets.isEmpty else { return [] }
        let step = max(1, Int((Double(buckets.count) / 5).rounded(.up)))
        // Ticks zu nah am rechten Rand weglassen – deren Beschriftung würde abgeschnitten
        let lastAllowed = Double(buckets.count - 1) - Double(step) / 2
        return stride(from: 0, to: buckets.count, by: step)
            .filter { $0 == 0 || Double($0) <= lastAllowed }
            .map { buckets[$0].start }
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded())) %"
    }
}

private extension View {
    func card() -> some View {
        padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
    }
}

// MARK: - Zusammenfassung

private struct SummaryCard: View {
    let snapshot: AnalyticsSnapshot

    private var periodText: String {
        let cal = Calendar.current
        let sameYear = cal.component(.year, from: snapshot.start) == cal.component(.year, from: snapshot.end)
        let from = (sameYear ? AnalyticsFormat.dayMonth : AnalyticsFormat.dayMonthYear).string(from: snapshot.start)
        let to = AnalyticsFormat.dayMonthYear.string(from: snapshot.end)
        return "\(from) – \(to) · \(snapshot.dayCount) \(snapshot.dayCount == 1 ? "Tag" : "Tage")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(periodText)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(AnalyticsFormat.percent(snapshot.overallRate))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("erfüllt")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            if let previous = snapshot.previousOverallRate {
                let delta = Int(((snapshot.overallRate - previous) * 100).rounded())
                HStack(spacing: 4) {
                    Image(systemName: delta > 0 ? "arrow.up.right" : delta < 0 ? "arrow.down.right" : "arrow.right")
                    Text("\(delta > 0 ? "+" : "")\(delta) %-Punkte ggü. Vorperiode (\(AnalyticsFormat.percent(previous)))")
                }
                .font(.footnote)
                .foregroundStyle(delta > 0 ? .green : delta < 0 ? .red : .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Streaks

private struct StreakBar: View {
    let snapshot: AnalyticsSnapshot

    var body: some View {
        HStack(spacing: 0) {
            ForEach(snapshot.goals) { goal in
                let s = snapshot.streaks[goal.id] ?? 0
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
}

// MARK: - Trend je Ziel

private struct TrendChart: View {
    let snapshot: AnalyticsSnapshot

    private struct Point: Identifiable {
        let goal: Goal
        let start: Date
        let rate: Double
        var id: String { "\(goal.id)-\(start.timeIntervalSince1970)" }
    }

    private var points: [Point] {
        snapshot.buckets.flatMap { bucket in
            snapshot.goals.map { Point(goal: $0, start: bucket.start, rate: bucket.goalRates[$0.id] ?? 0) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AnalyticsFormat.bucketTitle(snapshot.granularity))
                .font(.headline)

            if snapshot.granularity == .day {
                dayGrid
            } else {
                lineChart
            }
        }
    }

    /// Pro Tag gibt es je Ziel nur 0 % oder 100 % – als Linie unlesbar, daher Raster: Ziel × Tag.
    private var dayGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(snapshot.goals) { goal in
                HStack(spacing: 8) {
                    Image(systemName: goal.symbol)
                        .font(.caption)
                        .foregroundStyle(goal.color)
                        .frame(width: 20)
                    HStack(spacing: 2) {
                        ForEach(snapshot.buckets) { bucket in
                            let done = (bucket.goalRates[goal.id] ?? 0) > 0
                            RoundedRectangle(cornerRadius: 2)
                                .fill(done ? goal.color : Color(uiColor: .quaternarySystemFill))
                                .frame(maxWidth: .infinity)
                                .frame(height: 16)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(goal.name): an \(snapshot.buckets.filter { ($0.goalRates[goal.id] ?? 0) > 0 }.count) von \(snapshot.buckets.count) Tagen erledigt")
            }
            if let first = snapshot.buckets.first, let last = snapshot.buckets.last {
                HStack {
                    Text(AnalyticsFormat.dayMonth.string(from: first.start))
                    Spacer()
                    Text(AnalyticsFormat.dayMonth.string(from: last.start))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 28)
            }
        }
        .card()
    }

    private var lineChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Chart(points) { point in
                LineMark(
                    x: .value("Zeit", point.start),
                    y: .value("Quote", point.rate)
                )
                .foregroundStyle(by: .value("Ziel", point.goal.name))
                .symbol(by: .value("Ziel", point.goal.name))
                .symbolSize(snapshot.buckets.count <= 15 ? 30 : 0)
                .interpolationMethod(.monotone)
            }
            .chartForegroundStyleScale(
                domain: snapshot.goals.map(\.name),
                range: snapshot.goals.map(\.color)
            )
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks(values: AnalyticsFormat.ticks(snapshot.buckets)) { value in
                    AxisGridLine()
                    AxisValueLabel(anchor: .topLeading) {
                        if let date = value.as(Date.self) {
                            Text(AnalyticsFormat.axisLabel(date, granularity: snapshot.granularity))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0.0, 0.5, 1.0]) {
                    AxisGridLine()
                    AxisValueLabel(format: FloatingPointFormatStyle<Double>.Percent())
                }
            }
            .chartYScale(domain: 0...1)
            .frame(height: 220)
            .card()

            FlowLayout(spacing: 8) {
                ForEach(snapshot.goals) { goal in
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
    }
}

// MARK: - Gesamtfortschritt

private struct OverallChart: View {
    let snapshot: AnalyticsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gesamtfortschritt")
                .font(.headline)

            Chart(snapshot.buckets) { bucket in
                AreaMark(
                    x: .value("Zeit", bucket.start),
                    y: .value("Quote", bucket.overallRate)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.accentColor.opacity(0.15))
                LineMark(
                    x: .value("Zeit", bucket.start),
                    y: .value("Quote", bucket.overallRate)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.accentColor)
                .symbol(.circle)
                .symbolSize(snapshot.buckets.count <= 15 ? 30 : 0)
            }
            .chartXAxis {
                AxisMarks(values: AnalyticsFormat.ticks(snapshot.buckets)) { value in
                    AxisGridLine()
                    AxisValueLabel(anchor: .topLeading) {
                        if let date = value.as(Date.self) {
                            Text(AnalyticsFormat.axisLabel(date, granularity: snapshot.granularity))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0.0, 0.5, 1.0]) {
                    AxisGridLine()
                    AxisValueLabel(format: FloatingPointFormatStyle<Double>.Percent())
                }
            }
            .chartYScale(domain: 0...1)
            .frame(height: 160)
            .card()
        }
    }
}

// MARK: - Wochentage

private struct WeekdayChart: View {
    let snapshot: AnalyticsSnapshot

    var body: some View {
        let maxValue = max(snapshot.goals.count, 1)
        VStack(alignment: .leading, spacing: 10) {
            Text("Wochentage")
                .font(.headline)

            Chart(snapshot.weekdayPoints) { point in
                BarMark(
                    x: .value("Tag", point.weekdayLabel),
                    y: .value("Ø erledigte Ziele", point.average)
                )
                .foregroundStyle(by: .value("Ziel", point.goal.name))
            }
            .chartForegroundStyleScale(
                domain: snapshot.goals.map(\.name),
                range: snapshot.goals.map(\.color)
            )
            .chartLegend(.hidden)
            .chartYAxis {
                AxisMarks(values: Array(0...maxValue)) {
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYScale(domain: 0...maxValue)
            .frame(height: 180)
            .card()
        }
    }
}

// MARK: - Top-Kombinationen

private struct TopPairsSection: View {
    let snapshot: AnalyticsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top-Kombinationen")
                .font(.headline)

            VStack(spacing: 0) {
                if snapshot.topPairs.isEmpty {
                    Text("Im Zeitraum noch keine gemeinsam erledigten Ziele.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(Array(snapshot.topPairs.enumerated()), id: \.element.id) { index, pair in
                        HStack(spacing: 8) {
                            Label(pair.goal1.name, systemImage: pair.goal1.symbol)
                                .foregroundStyle(pair.goal1.color)
                            Text("+")
                                .foregroundStyle(.secondary)
                            Label(pair.goal2.name, systemImage: pair.goal2.symbol)
                                .foregroundStyle(pair.goal2.color)
                            Spacer()
                            Text("\(pair.count) \(pair.count == 1 ? "Tag" : "Tage")")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        if index < snapshot.topPairs.count - 1 {
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
}

// MARK: - Monatsübersicht

private struct MatrixSection: View {
    let matrix: MonthMatrix
    @Binding var page: Int

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        f.locale = Locale(identifier: "de_DE")
        return f
    }()

    private static let yearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        f.locale = Locale(identifier: "de_DE")
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Monatsübersicht")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { page += 1 }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!matrix.canGoBack)
                .accessibilityLabel("Frühere Monate")

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { page -= 1 }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!matrix.canGoForward)
                .padding(.leading, 12)
                .accessibilityLabel("Spätere Monate")
            }

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("")
                        .frame(width: 90, alignment: .leading)
                    ForEach(matrix.months, id: \.self) { month in
                        VStack(spacing: 0) {
                            Text(Self.monthFormatter.string(from: month))
                                .fontWeight(.semibold)
                            Text(Self.yearFormatter.string(from: month))
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)

                ForEach(matrix.rows) { row in
                    HStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: row.goal.symbol)
                                .font(.caption)
                                .foregroundStyle(row.goal.color)
                            Text(row.goal.name)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(width: 90, alignment: .leading)

                        ForEach(Array(row.rates.enumerated()), id: \.offset) { _, rate in
                            MatrixCell(rate: rate)
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

// MARK: - Layout

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
