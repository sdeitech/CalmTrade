//
//  TimelineItemType.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/01/26.
//

import Foundation

enum TimelineItemType: String, Decodable {
    case Trades, Emotion, NoTrade
}

struct TimelineItem: Decodable {
    let type: TimelineItemType
    let time: String?
    let timeRange: String?
    let symbol: String?
    let result: String?
    let summary: String?
    let reason: String?
    let emotion: String?
    let note: String?
    let metrics: Metrics?
    let colorCode: String?
    let entryPrice: Double?
}

struct Metrics: Decodable {
    let calmScore: Double?
    let heartRate: String?
    let hrv: String?
}
