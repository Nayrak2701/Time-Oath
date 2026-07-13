import SwiftUI
import UserNotifications

@main
struct AufstehenApp: App {
    // Bridge to UIKit so we can be the notification-center delegate.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Single shared store for the whole app.
    @StateObject private var store = AlarmStore.shared

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .active:
                        // Resume a locked wake cycle, or check for a due alarm.
                        store.resumeWakeIfNeeded()
                        store.reschedule()
                        store.checkForActiveAlarm()
                        store.handleForeground()
                    case .inactive, .background:
                        // Start the silent keep-alive audio while still
                        // foreground-privileged (.inactive precedes .background on
                        // lock) so it can ring on time even in DND / when locked.
                        store.handleBackground()
                    @unknown default:
                        break
                    }
                }
        }
    }
}

/// Handles notification-center callbacks and forwards them to the shared store.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Alarm notification arrives while the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        DispatchQueue.main.async {
            AlarmStore.shared.checkForActiveAlarm()
        }
        // Suppress the system banner/sound while foregrounded — the in-app ringing
        // view and looping sound take over so we stay in full control.
        completionHandler([])
    }

    // User tapped the alarm notification from the lock screen / banner.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            AlarmStore.shared.checkForActiveAlarm()
        }
        completionHandler()
    }
}
