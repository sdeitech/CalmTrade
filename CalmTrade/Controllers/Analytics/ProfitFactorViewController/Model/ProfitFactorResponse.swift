//
//  ProfitFactorResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 08/12/25.
//


// ProfitFactorResponse.swift
import Foundation

struct ProfitFactorResponse: Decodable {
    let status: Int?
    let success: Bool?
    let profitFactor: Double?
    let profitFactorRatio: String?
    let gauge: GaugeResponse?

    let totalWinsValue: Double?
    let totalLossesValue: Double?

    let winsPercent: Double?     // NEW
    let lossesPercent: Double?   // NEW

    let biometrics: BiometricsResponse?
}

struct GaugeResponse: Decodable {
    let percent: Double    // 0…100
    let color: String      // "red", "green", etc.
}

struct BiometricsResponse: Decodable {
    let calmScore: Int?
    let heartRate: Int?
    let hrv: Int?
    let sleep: SleepResponse?
}

struct SleepResponse: Decodable {
    let hours: Int?
    let minutes: Int?
}
