//
//  AppSettingViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 23/01/26.
//

import Foundation

struct AppSettingRow: Equatable {
    let iconName: String
    let title: String
    let action: Action

    enum Action {
        case notification
        case connectWearable
        case deleteAccount
        case logout
    }
}

final class AppSettingViewModel {

    // Outputs
    var onRows: (([AppSettingRow]) -> Void)?
    var onRoute: ((AppSettingRow.Action) -> Void)?

    // Header title (as per spec)
    let headerTitle = "App Settings"

    // Data
    private let rows: [AppSettingRow] = [
        .init(iconName: "setting_notification", title: "Notification",            action: .notification),
        .init(iconName: "setting_connectWearable",    title: "Connect Wearable",               action: .connectWearable),
        .init(iconName: "setting_deleteAccount",             title: "Delete Account",action: .deleteAccount),
        .init(iconName: "setting_logout",            title: "Logout",            action: .logout)
    ]

    // Lifecycle
    func load() { onRows?(rows) }

    // Inputs
    func didSelectRow(at index: Int) {
        guard rows.indices.contains(index) else { return }
        onRoute?(rows[index].action)
    }
}
