import UserNotifications

enum ReminderManager {
    static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    static func requestAccess() async throws -> Bool {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        guard granted else { throw ReminderError.denied }
        return true
    }

    static func enableDailySummary() async throws {
        let center = UNUserNotificationCenter.current()
        guard try await requestAccess() else { return }
        var date = DateComponents()
        date.hour = 20
        let content = UNMutableNotificationContent()
        content.title = "El día, en calma"
        content.body = "Si quieres, revisa los registros de hoy. No hace falta que todo sea perfecto."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "nido.daily-summary", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true))
        try await center.add(request)
    }

    static func disableDailySummary() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nido.daily-summary"])
    }

    static func disableFeedCheck() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nido.feed-check"])
    }

    static func scheduleFeedCheck(babyName: String, after hours: Int = 3) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["nido.feed-check"])
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Última toma"
        content.body = "Han pasado unas \(hours) horas desde la última toma registrada de \(babyName)."
        content.sound = .default
        try? await center.add(UNNotificationRequest(identifier: "nido.feed-check", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(hours * 3_600), repeats: false)))
    }
}

enum ReminderError: LocalizedError {
    case denied

    var errorDescription: String? {
        "Las notificaciones están desactivadas. Puedes permitirlas desde Ajustes del iPhone."
    }
}
