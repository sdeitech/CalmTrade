//
//  MonthOverviewResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 12/11/25.
//


// MARK: - Models

struct MonthOverviewResponse: Decodable {
    let status: Int
    let success: Bool
    let data: MonthOverviewData
}

struct MonthOverviewData: Decodable {
    let month: String
    let summary: MonthSummary
    let weeks: [Week]
}

struct MonthSummary: Decodable {
    let monthlyPnL: Double
    let avgCalmScore: Double
    let totalTrades: Int
}

struct Week: Decodable {
    let weekStart: String
    let weekEnd: String
    let weekTotal: WeekTotal
    let days: [Day]
}

struct WeekTotal: Decodable {
    let pnl: Double
    let calmScore: Double?
    let trades: Int
}

struct Day: Decodable {
    let date: String
    let pnl: Double
    let calmScore: Double?
    let trades: Int
}
