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

    // Existing
    let _id: String?
    let time: String?
    let timeRange: String?
    let symbol: String?
    let result: String?
    let resultR: Double?
    let summary: String?
    let reason: String?
    let emotion: String?
    let note: String?
    let metrics: Metrics?
    let colorCode: String?
    let entryPrice: Double?

    // 🔴 NEW – ISO timestamps from API
    let timestamp: String?
    let entryTime: String?
    let exitTime: String?
}

struct Metrics: Decodable {
    let calmScore: Double?
    let heartRate: String?
    let hrv: String?
}

enum TimelineDateFormatter {

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.timeZone = .current
        return f
    }()

    static func time(from iso: String?) -> String? {
        guard
            let iso,
            let date = isoFormatter.date(from: iso)
        else { return nil }

        return displayFormatter.string(from: date)
    }

    static func timeRange(entry: String?, exit: String?) -> String? {
        guard
            let start = time(from: entry),
            let end = time(from: exit)
        else { return nil }

        return "\(start)–\(end)"
    }
}
