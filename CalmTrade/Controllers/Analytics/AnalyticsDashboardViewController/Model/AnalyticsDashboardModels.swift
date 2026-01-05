//
//  AnalyticsDashboardResponse.swift
//  CalmTrade
//

import Foundation

// MARK: - API Root
struct StatsDashboardResponse: Decodable {
    let status: Int
    let success: Bool
    
    let winRate: WinRateDTO
    let avgGainLoss: AvgGainLossDTO
    let consecutive: ConsecutiveDTO
    let profitFactor: ProfitFactorDTO
    let cumulativePnL: CumulativePnLDTO
    let avgHoldTime: AvgHoldTimeDTO
    let biometrics: BiometricsDTO
}

// MARK: - Win Rate
struct WinRateDTO: Decodable {
    let winRate: Int
    let wins: Int
    let losses: Int
    let change: Int
    let avgCalmScore: Int
}

// MARK: - Avg Gain Loss
struct AvgGainLossDTO: Decodable {
    let avgGain: Double
    let avgLoss: Double
    let insight: String
}

// MARK: - Consecutive
struct ConsecutiveDTO: Decodable {
    let longestWin: Int
    let longestLoss: Int
    let insight: String
}

// MARK: - Profit Factor
struct ProfitFactorDTO: Decodable {
    let profitFactor: Double
    let insight: String
}

// MARK: - Cumulative PnL
struct CumulativePnLDTO: Decodable {
    let data: [CumulativePnLItemDTO]
    let insight: String
}

struct CumulativePnLItemDTO: Decodable {
    let date: String
    let value: Double
}

// MARK: - Hold Time
struct AvgHoldTimeDTO: Decodable {
    let winning: HoldDurationDTO
    let losing: HoldDurationDTO
    let insight: String
}

struct HoldDurationDTO: Decodable {
    let minutes: Int
    let seconds: Int
}

// MARK: - Biometrics
struct BiometricsDTO: Decodable {
    let heartRate: Int
    let hrv: Int
    let calmScore: Int
    let sleep: SleepDTO
}

struct SleepDTO: Decodable {
    let hours: Int
    let minutes: Int
}

//struct GrossDailyPnLResponse: Decodable {
//    let status: Int
//    let success: Bool
//    let range: String
//    let startDate: String
//    let endDate: String
//    let data: [DailyPnLItemDTO]
//}

struct DailyPnLItemDTO: Decodable {
    let date: String
    let pnl: Double
}


/// One bar in the Gross Daily P&L chart
//struct DailyPnLBar: Identifiable, Hashable {
//    let id = UUID()
//    let date: Date
//    let value: Double
//}

/// One point in the Gross Cumulative P&L chart
//struct CumulativePLPoint: Identifiable, Hashable {
//    let id = UUID()
//    let date: Date
//    let value: Double
//}

enum AnalyticsTimeframe {
    case recent      // e.g. last 30 days
    case custom      // Year/Month/Day -> detail screen
}
