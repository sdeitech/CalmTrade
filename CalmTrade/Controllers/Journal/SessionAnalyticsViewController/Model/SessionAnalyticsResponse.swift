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
