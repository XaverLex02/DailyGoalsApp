import Combine
import SwiftUI
import UIKit

@MainActor
class GoalsStore: ObservableObject {

    @AppStorage("goalsHistory") private var historyData: Data = Data()
    @AppStorage("goals") private var goalsData: Data = Data()

    private var _historyCache: [String: [String: Bool]]?
    private var _goalsCache: [Goal]?
    private var _firstTrackedDayCache: Date??
    private var _snapshotCache: [AnalyticsRange: AnalyticsSnapshot?] = [:]
    private var _snapshotCacheDay: Date?

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
            _firstTrackedDayCache = nil
            _snapshotCache = [:]
            objectWillChange.send()
            historyData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var goals: [Goal] {
        get {
            if let cache = _goalsCache { return cache }
            let decoded = (try? JSONDecoder().decode([Goal].self, from: goalsData)) ?? Goal.defaults
            _goalsCache = decoded
            return decoded
        }
        set {
            _goalsCache = newValue
            _snapshotCache = [:]
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
        let newHistory = Self.migrateLegacyKeys(existingHistory)
        _historyCache = newHistory
        historyData = (try? JSONEncoder().encode(newHistory)) ?? Data()
        goals = Goal.defaults
    }

    /// Schreibt alte `GoalType.rawValue`-Keys (z. B. "lesen") auf die festen UUIDs der Standardziele um.
    static func migrateLegacyKeys(_ history: [String: [String: Bool]]) -> [String: [String: Bool]] {
        history.mapValues { dayEntry in
            var newDayEntry: [String: Bool] = [:]
            for (goalKey, value) in dayEntry {
                let key = Goal.migrationMap[goalKey]?.uuidString ?? goalKey
                newDayEntry[key] = (newDayEntry[key] ?? false) || value
            }
            return newDayEntry
        }
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
        settings.notificationsEnabled = false
        settings.notificationHour = 20
        settings.notificationMinute = 0
        NotificationManager.cancel()
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

    /// Erster Tag mit History-Eintrag. Tage davor zählen in Quoten nicht als verfehlt.
    /// Gecacht (wird bei jeder History-Änderung invalidiert), da die Analytics es sehr oft abfragen.
    /// `yyyy-MM-dd`-Keys sortieren als String chronologisch → nur der kleinste gültige Key wird geparst.
    var firstTrackedDay: Date? {
        if let cached = _firstTrackedDayCache { return cached }
        let first = history.keys.sorted().lazy.compactMap { Self.dateFormatter.date(from: $0) }.first
        _firstTrackedDayCache = .some(first)
        return first
    }

    /// Gecachter Analyse-Snapshot für den Zeitraum (neu berechnet nach Änderungen oder Tageswechsel).
    func analyticsSnapshot(range: AnalyticsRange) -> AnalyticsSnapshot? {
        let today = Calendar.current.startOfDay(for: Date())
        if _snapshotCacheDay != today {
            _snapshotCache = [:]
            _snapshotCacheDay = today
        }
        if let cached = _snapshotCache[range] { return cached }
        let snapshot = computeAnalyticsSnapshot(range: range, today: today)
        _snapshotCache[range] = .some(snapshot)
        return snapshot
    }

    /// Monatsquote eines Ziels (für die Monatsmatrix). Zählt Tage ab `firstTrackedDay` bis heute.
    func monthlyRate(for goal: Goal, month: Date) -> Double? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = firstTrackedDay,
              let daysRange = cal.range(of: .day, in: .month, for: month) else { return nil }
        var compsBase = cal.dateComponents([.year, .month], from: month)
        var completed = 0, total = 0
        for day in daysRange {
            compsBase.day = day
            guard let dayDate = cal.date(from: compsBase), dayDate >= start, dayDate <= today else { continue }
            total += 1
            let key = Self.dateFormatter.string(from: dayDate)
            if history[key]?[goal.id.uuidString] == true { completed += 1 }
        }
        guard total > 0 else { return nil }
        return Double(completed) / Double(total)
    }

    // MARK: - Import / Export

    /// Export-Format: Ziele + History. Import akzeptiert zusätzlich das alte Format (nur History).
    struct Backup: Codable {
        var goals: [Goal]
        var history: [String: [String: Bool]]
    }

    func exportJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(Backup(goals: goals, history: history)) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    enum ImportError: LocalizedError {
        case invalidString
        case decodingFailed
        case invalidDate(String)
        case invalidGoalCount

        var errorDescription: String? {
            switch self {
            case .invalidString:         return "Ungültiger Text in der Zwischenablage."
            case .decodingFailed:        return "JSON konnte nicht dekodiert werden."
            case .invalidDate(let key):  return "Ungültiges Datum „\(key)“ (erwartet: yyyy-MM-dd)."
            case .invalidGoalCount:      return "Die Datei muss 1 bis 5 Ziele enthalten."
            }
        }
    }

    func importJSON(_ string: String) throws {
        guard let data = string.data(using: .utf8) else { throw ImportError.invalidString }
        let decoder = JSONDecoder()

        let importedGoals: [Goal]?
        let rawHistory: [String: [String: Bool]]
        if let backup = try? decoder.decode(Backup.self, from: data) {
            importedGoals = backup.goals
            rawHistory = backup.history
        } else if let legacy = try? decoder.decode([String: [String: Bool]].self, from: data) {
            importedGoals = nil
            rawHistory = legacy
        } else {
            throw ImportError.decodingFailed
        }

        for key in rawHistory.keys where Self.dateFormatter.date(from: key) == nil {
            throw ImportError.invalidDate(key)
        }
        if let importedGoals, !(1...5).contains(importedGoals.count) {
            throw ImportError.invalidGoalCount
        }

        if let importedGoals { goals = importedGoals }
        history = Self.migrateLegacyKeys(rawHistory)
    }
}
