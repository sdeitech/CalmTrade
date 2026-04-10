//
//  NotificationSettings.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/02/26.
//


struct NotificationSettings: Decodable {
    var stockDetails: Bool
    var heartRateIndications: Bool
    var subscriptionOffers: Bool
    var polarUpdates: Bool
    var emotionalSuggestions: Bool

    func toParams() -> [String: Any] {
        return [
            "settings": [
                "stockDetails": stockDetails,
                "heartRateIndications": heartRateIndications,
                "subscriptionOffers": subscriptionOffers,
                "polarUpdates": polarUpdates,
                "emotionalSuggestions": emotionalSuggestions
            ]
        ]
    }
}
