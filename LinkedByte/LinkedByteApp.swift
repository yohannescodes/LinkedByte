//
//  LinkedByteApp.swift
//  LinkedByte
//
//  Edited by Yohannes Haile on 6/11/25.

import SwiftUI
import UserNotifications
import Combine

class AppLaunchRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    
    static let shared = AppLaunchRouter()
    @Published var showDailySuggestion: Bool = false
    override private init() { super.init() }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.content.categoryIdentifier == "DAILY_POST" {
            DispatchQueue.main.async {
                self.showDailySuggestion = true
            }
        }
        completionHandler()
    }
}

@main
struct LinkedByteApp: App {

    init() {
        UNUserNotificationCenter.current().delegate = AppLaunchRouter.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppLaunchRouter.shared)
            // In ContentView, observe `showDailySuggestion` from environment object `AppLaunchRouter.shared`
            // and respond accordingly (e.g., present a daily suggestion view or alert).
        }
    }
}
