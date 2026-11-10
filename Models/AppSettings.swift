import SwiftUI
import Observation

@Observable
class AppSettings {

    // MARK: - Onboarding

    var hasLaunchedBefore: Bool = AppSettings.initialHasLaunchedBefore() {
        didSet { UserDefaults.standard.set(hasLaunchedBefore, forKey: "hasLaunchedBefore") }
    }

    /// Bestandsnutzer (History vorhanden, aber Version vor dem Onboarding) sollen das Onboarding
    /// nicht sehen – es würde ihre Ziele durch neue ersetzen und die History verwaisen lassen.
    private static func initialHasLaunchedBefore() -> Bool {
        let ud = UserDefaults.standard
        if ud.object(forKey: "hasLaunchedBefore") != nil {
            return ud.bool(forKey: "hasLaunchedBefore")
        }
        let hasHistory: Bool = {
            guard let data = ud.data(forKey: "goalsHistory"),
                  let history = try? JSONDecoder().decode([String: [String: Bool]].self, from: data)
            else { return false }
            return !history.isEmpty
        }()
        if hasHistory { ud.set(true, forKey: "hasLaunchedBefore") }
        return hasHistory
    }

    // MARK: - Theme

    var colorScheme: String = UserDefaults.standard.string(forKey: "colorScheme") ?? "system" {
        didSet { UserDefaults.standard.set(colorScheme, forKey: "colorScheme") }
    }

    var preferredColorScheme: ColorScheme? {
        switch colorScheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    // MARK: - Benachrichtigungen

    var notificationsEnabled: Bool = UserDefaults.standard.bool(forKey: "notificationsEnabled") {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    var notificationHour: Int = {
        let ud = UserDefaults.standard
        return ud.object(forKey: "notificationHour") != nil ? ud.integer(forKey: "notificationHour") : 20
    }() {
        didSet { UserDefaults.standard.set(notificationHour, forKey: "notificationHour") }
    }

    var notificationMinute: Int = UserDefaults.standard.integer(forKey: "notificationMinute") {
        didSet { UserDefaults.standard.set(notificationMinute, forKey: "notificationMinute") }
    }

    /// Hilfsproperty für DatePicker-Binding
    var notificationDate: Date {
        get {
            Calendar.current.date(bySettingHour: notificationHour, minute: notificationMinute, second: 0, of: Date()) ?? Date()
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            notificationHour = comps.hour ?? 20
            notificationMinute = comps.minute ?? 0
        }
    }
}
