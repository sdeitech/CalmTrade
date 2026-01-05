//
//  ProfileListViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 27/10/25.
//


import Foundation

struct ProfileRow: Equatable {
    let icon: String
    let title: String
    let action: Action

    enum Action {
        case manageSubscriptions
        case setAccountBalance
        case emotionalTags
        case accountDetails
        case setLocalTimeZone
        case device
    }
}

final class ProfileListViewModel {

    // Outputs
    var onRows: (([ProfileRow]) -> Void)?
    var onRoute: ((ProfileRow.Action) -> Void)?

    private let rows: [ProfileRow] = [
        .init(icon: "profile_manage_subs",  title: "Manage Subscriptions",  action: .manageSubscriptions),
        .init(icon: "profile_balance",      title: "Set Account Balance",   action: .setAccountBalance),
        .init(icon: "profile_emotions",     title: "Emotional Tags",        action: .emotionalTags),
        .init(icon: "profile_account",      title: "Account Details",       action: .accountDetails),
        .init(icon: "profile_timezone",     title: "Set local time zone",   action: .setLocalTimeZone),
        .init(icon: "profile_device",       title: "Device",                action: .device)
    ]

    func load() { onRows?(rows) }

    func didSelectRow(at index: Int) {
        guard rows.indices.contains(index) else { return }
        onRoute?(rows[index].action)
    }
}
