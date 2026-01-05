//
//  AverageTradeGainLossResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/12/25.
//


// AverageTradeGainLossResponse.swift
import Foundation

struct AverageTradeGainLossResponse: Decodable {
    let status: Int?
    let success: Bool?
    let avgGain: Double
    let avgLoss: Double
    let netAvgPerformance: Double
    let performanceBreakdown: PerformanceBreakdown
    let biometrics: Biometrics
}

struct PerformanceBreakdown: Decodable {
    let avgTradeGain: TradeMetric
    let avgTradeLoss: TradeMetric
    let netAvgPerformance: TradeMetric
}

struct TradeMetric: Decodable {
    let value: Double
    let progress: Double
}

struct Biometrics: Decodable {
    let calmScore: Int
    let heartRate: Int
    let hrv: Int
    let sleep: SleepInfo
}

struct SleepInfo: Decodable {
    let hours: Int
    let minutes: Int
}
