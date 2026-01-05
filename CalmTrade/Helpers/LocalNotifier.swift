//
//  LocalNotifier.swift
//  CalmTrade
//
//  Created by Anas Parekh on 18/12/25.
//


import UserNotifications
import Foundation

final class LocalNotifier {

    static func show(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let req = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil   // fires immediately
        )

        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}
