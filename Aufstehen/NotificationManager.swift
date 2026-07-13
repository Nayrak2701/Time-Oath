import Foundation
import UserNotifications

/// Schedules the local-notification backup. The real alarm sound comes from the
/// background-audio engine (works in DND); these notifications are the visual
/// lock-screen backup, plus a fallback in case the app was force-quit.
enum NotificationManager {

    static let pingInterval: TimeInterval = 5
    static let maxBurst = 40

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    private static func content(soundName: String) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = "Time Oath"
        c.body = S.t("Time to get up. Scan the QR code to stop the alarm.",
                     "Zeit aufzustehen. Scanne den QR-Code, um den Wecker zu stoppen.")
        c.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        if #available(iOS 15.0, *) { c.interruptionLevel = .timeSensitive }
        return c
    }

    /// Burst on the earliest fire; a single ping on every other upcoming fire.
    static func schedule(fireDates: [Date], window: TimeInterval, soundName: String) {
        let center = UNUserNotificationCenter.current()
        let now = Date()
        let upcoming = fireDates.filter { $0 > now }.sorted()
        guard let earliest = upcoming.first else { return }

        // Sustained burst on the nearest fire.
        var offset: TimeInterval = 0, index = 0
        while offset <= window && index < maxBurst {
            let t = earliest.addingTimeInterval(offset)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, t.timeIntervalSince(now)),
                                                            repeats: false)
            center.add(UNNotificationRequest(identifier: "alarm.burst.\(index)",
                                             content: content(soundName: soundName),
                                             trigger: trigger))
            offset += pingInterval
            index += 1
        }

        // One ping for each other upcoming fire (stay well under the 64 limit).
        for (i, date) in upcoming.dropFirst().prefix(12).enumerated() {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSince(now)),
                                                            repeats: false)
            center.add(UNNotificationRequest(identifier: "alarm.other.\(i)",
                                             content: content(soundName: soundName),
                                             trigger: trigger))
        }
    }
}
