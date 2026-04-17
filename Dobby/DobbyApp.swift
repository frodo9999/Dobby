import SwiftUI
import CoreData
import UserNotifications

@main
struct DobbyApp: App {
    @UIApplicationDelegateAdaptor(DobbyAppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    requestNotificationPermission()
                }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
}
