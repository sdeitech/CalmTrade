//
//  SubscriptionCheckoutResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 11/12/25.
//

import Foundation

/// Response wrapper for create-checkout-session
struct SubscriptionCheckoutResponse: Decodable {
    let status: Int?
    let success: Bool?
    let message: String?
    let data: SubscriptionCheckoutData?
}

/// Inner data object
struct SubscriptionCheckoutData: Decodable {
    let sessionId: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case sessionId
        case url   // API returns "url"
    }
}
