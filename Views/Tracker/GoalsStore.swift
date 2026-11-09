import Combine
import SwiftUI
import UIKit

@MainActor
class GoalsStore: ObservableObject {

    @AppStorage("goalsHistory") private var historyData: Data = Data()
    @AppStorage("goals") private var goalsData: Data = Data()

    private var _historyCache: [String: [String: Bool]]?

    // MARK: - Persistence

    var history: [String: [String: Bool]] {
        get {
            if let cache = _historyCache { return cache }
            let decoded = (try? JSONDecoder().decode([String: [String: Bool]].self, from: historyData)) ?? [:]
            _historyCache = decoded
            return decoded
        }
        set {
            _historyCache = newValue
            objectWillChange.send()
            historyData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var goals: [Goal] {
        get {
            (try? JSONDecoder().decode([Goal].self, from: goalsData)) ?? Goal.defaults
        }
        set {
            objectWillChange.send()
            goalsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    // MARK: - Init + Migration

    init() {
        migrateIfNeeded()
    }

    private func migrateIfNeeded() {
        guard goalsData.isEmpty || (try? JSONDecoder().decode([Goal].self, from: goalsData)) == nil else { return }
        let existingHistory = (try? JSONDecoder().decode([String: [String: Bool]].self, from: historyData)) ?? [:]
        guard !existingHistory.isEmpty else {
            goals = Goal.defaults
            return
        }
        // Alte History-Keys auf neue UUIDs umschreiben
        var newHistory: [String: [String: Bool]] = [:]
        for (dateKey, dayEntry) in existingHistory {
            var newDayEntry: [String: Bool] = [:]
            for (goalKey, value) in dayEntry {
                if let uuid = Goal.migrationMap[goalKey] {
                    newDayEntry[uuid.uuidString] = value
                } else {
                    newDayEntry[goalKey] = value
                }
            }
            newHistory[dateKey] = newDayEntry
        }
        _historyCache = newHistory
        historyData = (try? JSONEncoder().encode(newHistory)) ?? Data()
        goals = Goal.defaults
    }

    // MARK: - Date Formatting

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func key(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    // MARK: - Read

    func isCompleted(_ goal: Goal, for date: Date) -> Bool {
        history[Self.key(for: date)]?[goal.id.uuidString] ?? false
    }

    func completionCount(for date: Date) -> Int {
        goals.filter { isCompleted($0, for: date) }.count
    }

    func allCompleted(for date: Date) -> Bool {
        goals.allSatisfy { isCompleted($0, for: date) }
    }

    // MARK: - Write

    func toggle(_ goal: Goal, for date: Date) {
        let key = Self.key(for: date)
        var dayEntry = history[key] ?? [:]
        dayEntry[goal.id.uuidString] = !(dayEntry[goal.id.uuidString] ?? false)
        var updated = history
        updated[key] = dayEntry
        history = updated
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Goal Management

    func addGoal(_ goal: Goal) {
        guard goals.count < 5 else { return }
        goals.append(goal)
    }

    func removeGoal(_ goal: Goal) {
        guard goals.count > 1 else { return }
        goals.removeAll { $0.id == goal.id }
        var updated = history
        for (dateKey, dayEntry) in updated {
            var newEntry = dayEntry
            newEntry.removeValue(forKey: goal.id.uuidString)
            updated[dateKey] = newEntry
        }
        history = updated
    }

    func updateGoal(_ goal: Goal) {
        guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        goals[index] = goal
    }

    func resetApp(settings: AppSettings) {
        history = [:]
        goals = Goal.defaults
        settings.colorScheme = "system"
    }

    // MARK: - Streaks

    var currentStreak: Int {
        var count = 0
        var date = Calendar.current.startOfDay(for: Date())
        if !allCompleted(for: date) {
            date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        }
        while allCompleted(for: date) {
            count += 1
            date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        }
        return count
    }

    func streak(for goal: Goal) -> Int {
        var count = 0
        var date = Calendar.current.startOfDay(for: Date())
        if !isCompleted(goal, for: date) {
            date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        }
        while isCompleted(goal, for: date) {
            count += 1
            date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        }
        return count
    }

    // MARK: - Analytics

    func totalCompletions(for goal: Goal) -> Int {
        history.values.filter { $0[goal.id.uuidString] == true }.count
    }

    func monthlyRate(for goal: Goal) -> [(month: Date, rate: Double)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        var monthKeys = Set<String>()
        for dateKey in history.keys {
            guard Self.dateFormatter.date(from: dateKey) != nil else { continue }
            monthKeys.insert(String(dateKey.prefix(7)))
        }

        return monthKeys.compactMap { monthKey -> (month: Date, rate: Double)? in
            guard let firstDay = Self.dateFormatter.date(from: "\(monthKey)-01"),
                  let daysRange = cal.range(of: .day, in: .month, for: firstDay) else { return nil }
            var compsBase = cal.dateComponents([.year, .month], from: firstDay)
            var completed = 0, total = 0
            for day in daysRange {
                compsBase.day = day
                guard let dayDate = cal.date(from: compsBase), dayDate <= today else { continue }
                total += 1
                let key = Self.dateFormatter.string(from: dayDate)
                if history[key]?[goal.id.uuidString] == true { completed += 1 }
            }
            guard total > 0 else { return nil }
            return (month: firstDay, rate: Double(completed) / Double(total))
        }.sorted { $0.month < $1.month }
    }

    func monthlyRate(for goal: Goal, month: Date) -> Double? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let daysRange = cal.range(of: .day, in: .month, for: month) else { return nil }
        var compsBase = cal.dateComponents([.year, .month], from: month)
        var completed = 0, total = 0
        for day in daysRange {
            compsBase.day = day
            guard let dayDate = cal.date(from: compsBase), dayDate <= today else { continue }
            total += 1
            let key = Self.dateFormatter.string(from: dayDate)
            if history[key]?[goal.id.uuidString] == true { completed += 1 }
        }
        guard total > 0 else { return nil }
        return Double(completed) / Double(total)
    }

    func averageMonthlyRate(months: [Date]) -> [(month: Date, rate: Double)] {
        months.compactMap { month -> (month: Date, rate: Double)? in
            let rates = goals.compactMap { monthlyRate(for: $0, month: month) }
            guard !rates.isEmpty else { return nil }
            return (month: month, rate: rates.reduce(0, +) / Double(rates.count))
        }
    }

    struct WeekdayPoint: Identifiable {
        let id = UUID()
        let weekday: Int
        let weekdayLabel: String
        let goal: Goal
        let average: Double
    }

    private static let weekdayLabels: [Int: String] = [2: "Mo", 3: "Di", 4: "Mi", 5: "Do", 6: "Fr", 7: "Sa", 1: "So"]

    func weekdayAverages() -> [WeekdayPoint] {
        let cal = Calendar.current
        var counts: [Int: [UUID: (sum: Int, total: Int)]] = [:]
        for (dateKey, dayEntry) in history {
            guard let date = Self.dateFormatter.date(from: dateKey) else { continue }
            let wd = cal.component(.weekday, from: date)
            for goal in goals {
                let done = dayEntry[goal.id.uuidString] == true ? 1 : 0
                counts[wd, default: [:]][goal.id, default: (0, 0)].sum += done
                counts[wd, default: [:]][goal.id, default: (0, 0)].total += 1
            }
        }
        let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1]
        return orderedWeekdays.flatMap { wd -> [WeekdayPoint] in
            let label = Self.weekdayLabels[wd] ?? ""
            return goals.map { goal in
                let entry = counts[wd]?[goal.id]
                let avg = entry.map { Double($0.sum) / Double($0.total) } ?? 0
                return WeekdayPoint(weekday: wd, weekdayLabel: label, goal: goal, average: avg)
            }
        }
    }

    struct GoalPair: Identifiable {
        let id = UUID()
        let goal1: Goal
        let goal2: Goal
        let count: Int
    }

    func topPairs(limit: Int = 5) -> [GoalPair] {
        let currentGoals = goals
        var pairCounts: [String: (Goal, Goal, Int)] = [:]
        for i in 0..<currentGoals.count {
            for j in (i+1)..<currentGoals.count {
                let key = "\(currentGoals[i].id)+\(currentGoals[j].id)"
                pairCounts[key] = (currentGoals[i], currentGoals[j], 0)
            }
        }
        for dayEntry in history.values {
            for i in 0..<currentGoals.count {
                for j in (i+1)..<currentGoals.count {
                    guard dayEntry[currentGoals[i].id.uuidString] == true,
                          dayEntry[currentGoals[j].id.uuidString] == true else { continue }
                    let key = "\(currentGoals[i].id)+\(currentGoals[j].id)"
                    pairCounts[key]?.2 += 1
                }
            }
        }
        return pairCounts.values
            .sorted { $0.2 > $1.2 }
            .prefix(limit)
            .filter { $0.2 > 0 }
            .map { GoalPair(goal1: $0.0, goal2: $0.1, count: $0.2) }
    }

    // MARK: - Import / Export

    func exportJSON() -> String? {
        guard let data = try? JSONEncoder().encode(history) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    enum ImportError: LocalizedError {
        case invalidString
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .invalidString:  return "Ungültiger Text in der Zwischenablage."
            case .decodingFailed: return "JSON konnte nicht dekodiert werden."
            }
        }
    }

    func importJSON(_ string: String) throws {
        guard let data = string.data(using: .utf8) else { throw ImportError.invalidString }
        guard let decoded = try? JSONDecoder().decode([String: [String: Bool]].self, from: data) else {
            throw ImportError.decodingFailed
        }
        history = decoded
    }
}
