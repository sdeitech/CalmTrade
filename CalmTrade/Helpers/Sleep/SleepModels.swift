//
//  CTSleepStage.swift
//  CalmTrade
//
//  Created by Anas Parekh on 10/10/25.
//


import Foundation

public enum CTSleepStage: Int, Codable, CaseIterable {
    case awake, rem, light, deep
}

public struct CTSleepSegment: Codable, Equatable {
    public let start: Date
    public let end: Date
    public let stage: CTSleepStage
    public let quality: String?  // "good"/"fair"/"poor"/nil
    public init(start: Date, end: Date, stage: CTSleepStage, quality: String? = nil) {
        self.start = start; self.end = end; self.stage = stage; self.quality = quality
    }
}

public struct CTSleepEpisode: Codable, Equatable {
    public let date: Date              // typically the sleep end date
    public let source: CTMetricSource  // .appleHealth / .polar360
    public let segments: [CTSleepSegment]
    public let totalSeconds: TimeInterval
    public let byStageSeconds: [CTSleepStage: TimeInterval]
    public let qualityFlag: String?    // "good"/"fair"/"poor"/"mixed"/nil

    public init(date: Date, source: CTMetricSource, segments: [CTSleepSegment], qualityFlag: String?) {
        self.date = date
        self.source = source
        self.segments = segments.sorted { $0.start < $1.start }
        // rollups
        var total: TimeInterval = 0
        var stageBins: [CTSleepStage: TimeInterval] = [:]
        for s in segments {
            let d = s.end.timeIntervalSince(s.start)
            total += d
            stageBins[s.stage, default: 0] += d
        }
        self.totalSeconds = total
        self.byStageSeconds = stageBins
        self.qualityFlag = qualityFlag
    }
}


