import UserNotifications

/// Tägliche Erinnerung als einzelne, datierte Benachrichtigungen für die nächsten `daysAhead` Tage.
///
/// Statt eines wiederholenden Triggers wird jeder Tag einzeln geplant, damit der Text die noch offenen
/// Ziele nennen kann und die Erinnerung für heute entfällt, sobald alles erledigt ist. Neu geplant wird
/// bei jeder Änderung an Zielen/History und beim Öffnen der App (`GoalsStore.rescheduleReminders`).
/// Einschränkung: Wird die App länger als `daysAhead` Tage nicht geöffnet, enden die Erinnerungen.
struct NotificationManager {
    /// Alte ID des früheren wiederholenden Triggers – wird beim Neuplanen mit entfernt.
    static let legacyIdentifier = "dailyGoalsReminder"
    static let daysAhead = 30

    @discardableResult
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Plant die Erinnerungen neu.
    /// - Parameters:
    ///   - openGoalsToday: Namen der heute noch offenen Ziele (leer → heute keine Erinnerung)
    ///   - allGoals: Namen aller Ziele (für künftige Tage sind alle offen)
    static func schedule(hour: Int, minute: Int, openGoalsToday: [String], allGoals: [String], now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: allIdentifiers(around: now))

        let cal = Calendar.current
        let today = cal.startOfDay(for: now)

        for offset in 0..<daysAhead {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: day)
            comps.hour = hour
            comps.minute = minute
            guard let fireDate = cal.date(from: comps), fireDate > now else { continue }

            let open = offset == 0 ? openGoalsToday : allGoals
            guard !open.isEmpty else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Tages-Ziele"
            content.body = "Noch offen: \(formatList(open))"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: identifier(for: day), content: content, trigger: trigger))
        }

        // Heute schon alles erledigt → bereits zugestellte Erinnerung von heute entfernen
        if openGoalsToday.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: [identifier(for: today)])
        }
    }

    static func cancel(now: Date = Date()) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: allIdentifiers(around: now))
    }

    // MARK: - Helfer

    private static let idFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func identifier(for day: Date) -> String {
        "\(legacyIdentifier)-\(idFormatter.string(from: day))"
    }

    /// IDs aller Tage, die von einer früheren Planung noch ausstehen könnten (inkl. alter ID).
    private static func allIdentifiers(around now: Date) -> [String] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let days = (-1...daysAhead).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
        return [legacyIdentifier] + days.map(identifier(for:))
    }

    /// „Lesen“, „Lesen und Sport“, „Lesen, Sport und Lernen“
    private static func formatList(_ items: [String]) -> String {
        let f = ListFormatter()
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: items) ?? items.joined(separator: ", ")
    }
}
