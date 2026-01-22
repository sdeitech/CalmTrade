//
//  TimelineResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/01/26.
//

import Foundation

struct TimelineResponse: Decodable {
    let success: Bool
    let data: TimelineData
}

struct TimelineData: Decodable {
    let sessionSummary: SessionSummary
    let timeline: [TimelineItem]
}

struct SessionSummary: Decodable {

    let date: String
    let totalSessions: Int

    let pnl: Double
    let pnlR: Double?
    let trades: Int

    let calmScore: Int?
    let sleep: Double?

    let winningTrades: Int
    let losingTrades: Int

    let riskLimits: RiskLimits?
}

struct RiskLimits: Decodable {
    let maxLossPerTrade:  Double
    let maxLossPerSession: Double
    let maxLossPerTradeR:  Double
    let maxLossPerSessionR: Double
}

