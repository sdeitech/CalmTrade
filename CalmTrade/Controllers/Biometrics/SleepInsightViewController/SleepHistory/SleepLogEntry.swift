//
//  SleepLogEntry.swift
//  CalmTrade
//
//  Created by Anas Parekh on 17/11/25.
//

import Foundation

public struct SleepLogEntry: Hashable {
    public let sessionStart: Date
    public let sessionEnd: Date
    public let totalSeconds: TimeInterval
    public let remSeconds: TimeInterval
    public let coreSeconds: TimeInterval
    public let deepSeconds: TimeInterval
    public let awakeSeconds: TimeInterval
    public let source: SleepDataSource

    public init(
        sessionStart: Date,
        sessionEnd: Date,
        totalSeconds: TimeInterval,
        remSeconds: TimeInterval,
        coreSeconds: TimeInterval,
        deepSeconds: TimeInterval,
        awakeSeconds: TimeInterval,
        source: SleepDataSource
    ) {
        self.sessionStart = sessionStart
        self.sessionEnd = sessionEnd
        self.totalSeconds = totalSeconds
        self.remSeconds = remSeconds
        self.coreSeconds = coreSeconds
        self.deepSeconds = deepSeconds
        self.awakeSeconds = awakeSeconds
        self.source = source
    }

    public var totalHours: Double { totalSeconds / 3600 }
}
