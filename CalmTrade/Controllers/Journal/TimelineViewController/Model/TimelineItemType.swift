//
//  TimelineItemType.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/01/26.
//

import Foundation

enum TimelineItemType: Decodable, Equatable, Hashable {
    case trade
    case emotion
    case noTrade
    case unknown(String)

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)

        switch value {
        case "Trade":
            self = .trade
        case "Emotion":
            self = .emotion
        case "NoTrade":
            self = .noTrade
        default:
            self = .unknown(value)
        }
    }
}

struct TimelineItem: Decodable {

    let type: TimelineItemType

    // MARK: - Trade Fields (NEW)
    let quantity: Int?
    let side: String?
    let pnl: Double?
    let price: DecimalWrapper?
    let notes: String?

    // MARK: - Existing
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

    // MARK: - ISO timestamps
    let timestamp: String?
    let entryTime: String?
    let exitTime: String?
}

struct Metrics: Decodable {
    let calmScore: Double?
    let heartRate: String?
    let hrv: String?
}

struct DecimalWrapper: Decodable {

    let value: Double

    enum CodingKeys: String, CodingKey {
        case numberDecimal = "$numberDecimal"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let string = try container.decode(String.self, forKey: .numberDecimal)
        value = Double(string) ?? 0
    }
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
