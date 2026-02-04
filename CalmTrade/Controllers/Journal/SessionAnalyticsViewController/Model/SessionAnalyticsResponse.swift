//
//  SessionAnalyticsResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 13/01/26.
//


import Foundation

struct SessionAnalyticsResponse: Decodable {
    let status: Int
    let success: Bool
    let data: SessionAnalyticsData
}

struct SessionAnalyticsData: Decodable {
    let date: String
    let pl: PLBlock
    let winRate: WinRateBlock
    let drawdown: DrawdownBlock
    let calmScore: CalmScoreBlock
    let noTrades: NoTradeBlock
    let emotionCounter: EmotionBlock
}

struct PLBlock: Decodable {
    let valueR: Double
    let valueUSD: Double
    let label: String
    let subLabel: String
}

struct WinRateBlock: Decodable {
    let percentage: Int
    let wins: Int
    let losses: Int
    let label: String
    let subLabel: String
}

struct DrawdownBlock: Decodable {
    let maxDrawdownR: Double
    let label: String
    let subLabel: String
}

struct CalmScoreBlock: Decodable {
    let value: Int?
    let stressLevel: String?
    let sleepHours: Double?
}

struct DecimalValue: Decodable {
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: String].self)
        value = Double(dict["$numberDecimal"] ?? "0") ?? 0
    }
}

struct NoTradeBlock: Decodable {
    let count: Int?
    let label: String?
}

struct EmotionBlock: Decodable {
    let primaryEmotion: String?
    let primaryCategory: String?
    let primaryCount: Int?
    let totalTags: Int?
    let breakdown: [breakdownBlock]
    let negative : Int?
    let neutral : Int?
    let cognitive : Int?
    let positive : Int?
}

struct breakdownBlock: Decodable {
    let emotion: String
    let count: Int
    let colorCode: String
    

    enum CodingKeys: String, CodingKey {
        case emotion
        case count
        case colorCode
    }
}
