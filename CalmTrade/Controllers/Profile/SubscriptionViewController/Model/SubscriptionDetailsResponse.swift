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
    let status: String?
    let isDefaultFreePlan: Bool?
    let startDate: String?
    let expiryDate: String?
    let trialEndDate: String?
    let autoRenew: Bool?
    let planDetails: SubscriptionPlanDetails?
}

struct SubscriptionPlanDetails: Decodable {
    let planId: String?
    let name: String?
    let displayName: String?
    let price: Double?
    let billingCycle: String?
    let features: [SubscriptionFeature]?
    let description: String?
    let isAddon: Bool?
    let gradient: String?
    let color: String?
    let currency: String?
    let isPopular: Bool?
    let tagline: String?
    let trialPeriodDays: Int?
}

struct SubscriptionFeature: Decodable {
    let key: String?
    let name: String?
    let hasAccess: Bool?
}

