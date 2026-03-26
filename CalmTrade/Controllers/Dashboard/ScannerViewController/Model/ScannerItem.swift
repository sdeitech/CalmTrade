//
//  ScannerItem.swift
//  CalmTrade
//
//  Created by Anas Parekh on 18/03/26.
//


import Foundation

struct ScannerItem {
    let symbol: String
    var pctUp: Double
    var lastPrice: Double
    var high: Double
    var low: Double
    var volume: Int
    var floatShares: Int?
    var rvo: Double?
    var hasNews: Bool
    var rank: Int

    // UI State (ephemeral)
    var highlights: Set<HighlightType> = []
    var highlightTimestamp: Date?
}

enum HighlightType {
    case pctSurge
    case rankSurge
    case hod
}
