//
//  UserNotificationManager.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import MenuBarModel
import UserNotifications

@MainActor
final class UserNotificationManager {
    private let diagLog = DiagLog(category: "UserNotificationManager")

    var notificationCenter: UNUserNotificationCenter {
        .current()
    }

    /// Requests authorization to allow user notifications for the app.
    func requestAuthorization() {
        Task {
            do {
                try await notificationCenter.requestAuthorization(options: [.badge, .alert, .sound])
            } catch {
                diagLog.error("Failed to request notification authorization: \(error)")
            }
        }
    }

    /// Schedules the delivery of a local notification.
    func addRequest(with identifier: UserNotificationIdentifier, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: identifier.rawValue,
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
    }
}
