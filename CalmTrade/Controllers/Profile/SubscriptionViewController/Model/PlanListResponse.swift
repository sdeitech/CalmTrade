//
//  PlanListResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 11/12/25.
//


struct PlanListResponse: Decodable {
    let status: Int?
    let success: Bool?
    let data: [SubscriptionPlan]?
}

struct SubscriptionPlan: Decodable {
    let planId: String
    let name: String
    let displayName: String
    let price: Double
    let billingCycle: String
    let features: [PlanFeature]
    let isAddon: Bool
}

struct PlanFeature: Decodable {
    let name: String
    let included: Bool
}
