import SwiftUI
import UserNotifications

@main
struct SpendlyApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var pro = ProStore()

    init() {
        #if DEBUG
        DemoData.seedIfRequested(SpendlyEnvironment.store)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: SpendlyEnvironment.store)
                .environment(pro)
                .task { await pro.start() }
        }
    }
}

/// Shows reminders and budget alerts as banners even while the app is open.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
