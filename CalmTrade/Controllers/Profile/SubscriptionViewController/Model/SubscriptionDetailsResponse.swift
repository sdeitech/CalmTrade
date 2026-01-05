//
//  SubscriptionDetailsResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 15/12/25.
//

import Foundation

struct SubscriptionDetailsResponse: Decodable {
    let status: Int?
    let success: Bool?
    let data: [SubscriptionRecord]?
}

struct SubscriptionRecord: Decodable {
    let planId: String
    let status: String
    let startDate: String?
    let expiryDate: String?
    let trialEndDate: String?
    let autoRenew: Bool?
    let planDetails: SubscriptionPlanDetails?
}

struct SubscriptionPlanDetails: Decodable {
    let planId: String
    let name: String
    let displayName: String
    let price: Double
    let billingCycle: String
    let features: [SubscriptionFeature]
}

struct SubscriptionFeature: Decodable {
    let name: String
    let included: Bool
}
