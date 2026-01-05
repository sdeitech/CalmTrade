//
//  OverallStatsModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 10/11/25.
//


import Foundation

struct OverallStatsResponse: Decodable {
    let status: Int?
    let success: Bool?
    let message: String?
    let data: OverallStatsData?
}

struct OverallStatsData: Decodable {
    let totalGainLoss: String?
    let largestGain: String?
    let largestLoss: String?
    let averageDailyGainLoss: String?
    let averageDailyVolume: String?
    let averagePerShareGainLoss: String?
    let avgWinnerPerShare: Double?
    let avgLoserPerShare: Double?
    let averageTradeGainLoss: String?
    let averageWinningTrade: String?
    let averageLosingTrade: String?
    let profitFactor: Double?
    let totalTrades: Int?
    let winningTrades: Int?
    let losingTrades: Int?
    let winningPercent: String?
    let losingPercent: String?
}
