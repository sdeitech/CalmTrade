//
//  TradeListResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 24/11/25.
//

import Foundation
import UIKit

// MARK: - API Response Model
struct TradeListResponse: Decodable {
    let status: Int?
    let success: Bool?
    let count: Int?
    let data: [TradeItem]?
}

// MARK: - Trade Item
struct TradeItem: Decodable, Hashable {
    let date: String
    let symbol: String
    let volume: Int
    let executions: Int
    let pnl: Double

    var id: String {
        return "\(date)-\(symbol)-\(volume)-\(executions)-\(pnl)"
    }
}

// MARK: - Grid Row Model (UPDATED)
struct TradeGridRow {
    let values: [String]       // 5 column values
    let colors: [UIColor?]     // color for each column
    let isSummary: Bool        // NEW → used for TOTAL + AVERAGE rows + header rows
}

// MARK: - GridItem (unused but keep if needed later)
struct GridItem: Hashable {
    let row: Int
    let col: Int
}
