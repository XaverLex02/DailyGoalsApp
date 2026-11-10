import Foundation

// MARK: - Zeitraum & Granularität

enum AnalyticsRange: String, CaseIterable, Identifiable {
    case days30, months3, months12, all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .days30:   return "30 Tage"
        case .months3:  return "3 Monate"
        case .months12: return "12 Monate"
        case .all:      return "Gesamt"
        }
    }
}

enum AnalyticsGranularity: Equatable {
    case day, week, month, quarter
}

// MARK: - Snapshot

/// Alle Analyse-Werte für einen Zeitraum, in einem Durchlauf über die Tage berechnet.
/// Wird im `GoalsStore` gecacht und bei jeder Änderung von History/Zielen invalidiert.
struct AnalyticsSnapshot: Equatable {

    struct Bucket: Equatable, Identifiable {
        let start: Date
        /// Quote je Ziel (Key: Goal-ID) in diesem Abschnitt
        let goalRates: [UUID: Double]
        /// Durchschnitt über alle Ziele
        let overallRate: Double
        var id: Date { start }
    }

    struct WeekdayPoint: Equatable, Identifiable {
        let weekday: Int
        let weekdayLabel: String
        let goal: Goal
        let average: Double
        var id: String { "\(weekday)-\(goal.id)" }
    }

    struct GoalPair: Equatable, Identifiable {
        let goal1: Goal
        let goal2: Goal
        let count: Int
        var id: String { "\(goal1.id)+\(goal2.id)" }
    }

    let range: AnalyticsRange
    let goals: [Goal]
    /// Tatsächlicher Beginn (frühestens der erste erfasste Tag)
    let start: Date
    let end: Date
    let dayCount: Int
    let granularity: AnalyticsGranularity
    let buckets: [Bucket]
    let overallRate: Double
    /// Quote im gleich langen Zeitraum direkt davor (nil, wenn dort keine Daten)
    let previousOverallRate: Double?
    let weekdayPoints: [WeekdayPoint]
    let topPairs: [GoalPair]
    /// Aktuelle Streaks je Ziel (zeitraumunabhängig)
    let streaks: [UUID: Int]
}

// MARK: - Berechnung

extension GoalsStore {

    /// Kalender für Analytics: Woche beginnt am Montag
    static var analyticsCalendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    private static let weekdayLabels: [Int: String] = [2: "Mo", 3: "Di", 4: "Mi", 5: "Do", 6: "Fr", 7: "Sa", 1: "So"]

    func computeAnalyticsSnapshot(range: AnalyticsRange, today: Date) -> AnalyticsSnapshot? {
        guard let firstDay = firstTrackedDay else { return nil }
        let cal = Self.analyticsCalendar
        let today = cal.startOfDay(for: today)
        guard firstDay <= today else { return nil }

        // Zeitraum bestimmen
        let nominalStart: Date
        switch range {
        case .days30:   nominalStart = cal.date(byAdding: .day, value: -29, to: today) ?? today
        case .months3:  nominalStart = cal.date(byAdding: .day, value: 1, to: cal.date(byAdding: .month, value: -3, to: today) ?? today) ?? today
        case .months12: nominalStart = cal.date(byAdding: .day, value: 1, to: cal.date(byAdding: .month, value: -12, to: today) ?? today) ?? today
        case .all:      nominalStart = firstDay
        }
        let start = max(nominalStart, firstDay)
        let dayCount = (cal.dateComponents([.day], from: start, to: today).day ?? 0) + 1

        let granularity: AnalyticsGranularity
        switch range {
        case .days30:   granularity = .day
        case .months3:  granularity = .week
        case .months12: granularity = .month
        case .all:
            let months = cal.dateComponents([.month], from: start, to: today).month ?? 0
            granularity = months > 24 ? .quarter : .month
        }

        let currentGoals = goals
        let currentHistory = history
        let goalKeys = currentGoals.map(\.id.uuidString)

        // Ein Durchlauf über alle Tage im Zeitraum
        var bucketOrder: [Date] = []
        var bucketDays: [Date: Int] = [:]
        var bucketDone: [Date: [Int]] = [:]          // Index = Zielposition
        var weekdayDays: [Int: Int] = [:]
        var weekdayDone: [Int: [Int]] = [:]
        var pairCounts = Array(repeating: Array(repeating: 0, count: currentGoals.count), count: currentGoals.count)
        var totalDone = 0

        var day = start
        while day <= today {
            let entry = currentHistory[Self.key(for: day)] ?? [:]
            let done = goalKeys.map { entry[$0] == true }

            let bucket = Self.bucketStart(for: day, granularity: granularity, calendar: cal)
            if bucketDays[bucket] == nil {
                bucketOrder.append(bucket)
                bucketDone[bucket] = Array(repeating: 0, count: currentGoals.count)
            }
            bucketDays[bucket, default: 0] += 1

            let wd = cal.component(.weekday, from: day)
            weekdayDays[wd, default: 0] += 1
            if weekdayDone[wd] == nil { weekdayDone[wd] = Array(repeating: 0, count: currentGoals.count) }

            for i in done.indices where done[i] {
                bucketDone[bucket]![i] += 1
                weekdayDone[wd]![i] += 1
                totalDone += 1
                for j in (i + 1)..<done.count where done[j] {
                    pairCounts[i][j] += 1
                }
            }

            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        let goalCount = max(currentGoals.count, 1)

        let buckets: [AnalyticsSnapshot.Bucket] = bucketOrder.map { b in
            let days = Double(bucketDays[b] ?? 1)
            let doneCounts = bucketDone[b] ?? []
            var rates: [UUID: Double] = [:]
            for (i, goal) in currentGoals.enumerated() {
                rates[goal.id] = Double(doneCounts[i]) / days
            }
            let overall = Double(doneCounts.reduce(0, +)) / (days * Double(goalCount))
            return .init(start: b, goalRates: rates, overallRate: overall)
        }

        let overallRate = Double(totalDone) / (Double(dayCount) * Double(goalCount))

        // Vorperiode: gleich lang, direkt vor `start`, begrenzt auf ersten erfassten Tag
        var previousRate: Double?
        if range != .all, let prevEnd = cal.date(byAdding: .day, value: -1, to: start), prevEnd >= firstDay {
            let prevStart = max(cal.date(byAdding: .day, value: -dayCount, to: start) ?? firstDay, firstDay)
            var prevDone = 0, prevDays = 0
            var d = prevStart
            while d <= prevEnd {
                let entry = currentHistory[Self.key(for: d)] ?? [:]
                prevDone += goalKeys.filter { entry[$0] == true }.count
                prevDays += 1
                guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
                d = next
            }
            if prevDays > 0 {
                previousRate = Double(prevDone) / (Double(prevDays) * Double(goalCount))
            }
        }

        let weekdayPoints: [AnalyticsSnapshot.WeekdayPoint] = [2, 3, 4, 5, 6, 7, 1].flatMap { wd in
            currentGoals.enumerated().map { i, goal in
                let days = weekdayDays[wd] ?? 0
                let avg = days > 0 ? Double(weekdayDone[wd]?[i] ?? 0) / Double(days) : 0
                return .init(weekday: wd, weekdayLabel: Self.weekdayLabels[wd] ?? "", goal: goal, average: avg)
            }
        }

        // Paare in fester Zielreihenfolge sammeln → stabile Sortierung bei Gleichstand
        var pairs: [AnalyticsSnapshot.GoalPair] = []
        for i in currentGoals.indices {
            for j in (i + 1)..<currentGoals.count where pairCounts[i][j] > 0 {
                pairs.append(.init(goal1: currentGoals[i], goal2: currentGoals[j], count: pairCounts[i][j]))
            }
        }
        let topPairs = pairs.enumerated()
            .sorted { $0.element.count != $1.element.count ? $0.element.count > $1.element.count : $0.offset < $1.offset }
            .prefix(5)
            .map(\.element)

        var streaks: [UUID: Int] = [:]
        for goal in currentGoals { streaks[goal.id] = streak(for: goal) }

        return AnalyticsSnapshot(
            range: range, goals: currentGoals, start: start, end: today, dayCount: dayCount,
            granularity: granularity, buckets: buckets, overallRate: overallRate,
            previousOverallRate: previousRate, weekdayPoints: weekdayPoints,
            topPairs: Array(topPairs), streaks: streaks
        )
    }

    static func bucketStart(for day: Date, granularity: AnalyticsGranularity, calendar cal: Calendar) -> Date {
        switch granularity {
        case .day:
            return day
        case .week:
            return cal.dateInterval(of: .weekOfYear, for: day)?.start ?? day
        case .month:
            return cal.date(from: cal.dateComponents([.year, .month], from: day)) ?? day
        case .quarter:
            var comps = cal.dateComponents([.year, .month], from: day)
            comps.month = ((comps.month ?? 1) - 1) / 3 * 3 + 1
            return cal.date(from: comps) ?? day
        }
    }
}
