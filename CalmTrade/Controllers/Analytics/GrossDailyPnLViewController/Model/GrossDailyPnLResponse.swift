//
//  GrossDailyPnLResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 01/12/25.
//

import Foundation

struct GrossDailyPnLResponse: Decodable {
    let status: Int?
    let success: Bool?
    let range: String?
    let startDate: String?
    let endDate: String?
    let data: [GrossDailyPnLEntry]?
}

struct GrossDailyPnLEntry: Decodable {
    let date: String
    let pnl: Double
}

struct DailyPnLBar: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
