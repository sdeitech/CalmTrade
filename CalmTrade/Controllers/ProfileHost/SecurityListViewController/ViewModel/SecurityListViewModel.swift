//
//  SecurityListViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 28/10/25.
//

import Foundation

struct SecurityRow: Equatable {
    let iconName: String
    let title: String
    let action: Action

    enum Action {
        case changePassword
        case changeEmail
        case twoFactor
        case dataManagement
    }
}

final class SecurityListViewModel {

    // Outputs
    var onRows: (([SecurityRow]) -> Void)?
    var onRoute: ((SecurityRow.Action) -> Void)?

    // Header title (as per spec)
    let headerTitle = "Security Setting"

    // Data
    private let rows: [SecurityRow] = [
        .init(iconName: "security_change_password", title: "Change Password",            action: .changePassword),
        .init(iconName: "security_change_email",    title: "Change Email",               action: .changeEmail),
        .init(iconName: "security_2fa",             title: "Two - Factor Authentication",action: .twoFactor),
        .init(iconName: "security_data",            title: "Data Management",            action: .dataManagement)
    ]

    // Lifecycle
    func load() { onRows?(rows) }

    // Inputs
    func didSelectRow(at index: Int) {
        guard rows.indices.contains(index) else { return }
        onRoute?(rows[index].action)
    }
}
