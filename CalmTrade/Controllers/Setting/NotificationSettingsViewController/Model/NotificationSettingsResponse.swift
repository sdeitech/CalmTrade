//
//  NotificationSettingsResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/02/26.
//


struct NotificationSettingsResponse: Decodable {
    let status: Int
    let success: Bool
    let data: NotificationSettingsData
}

struct NotificationSettingsData: Decodable {
    let settings: NotificationSettings
}
