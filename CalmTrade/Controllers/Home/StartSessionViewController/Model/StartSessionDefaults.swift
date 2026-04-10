//
//  StartSessionDefaults.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/12/25.
//

import Foundation

struct StartSessionResponse: Decodable {
    let success: Bool?
    let message: String?
}

struct PreviousRiskLimitsResponse: Decodable {
    let success: Bool
    let data: RiskLimitsData?
}

struct RiskLimitsData: Decodable {
    let maxLossPerTrade: Double
    let maxLossPerSession: Double
}
