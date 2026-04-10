//
//  BiometricData.swift
//  CalmTrade
//
//  Created by Anas Parekh on 02/09/25.
//

import Foundation

/// A struct to hold the processed and formatted data for display in the BiometricsViewController.
struct BiometricData {
    var lastUpdateTimestamp: String = "Updating..."

    // Values are Strings to handle formatting and default states like "--"
    var calmScore: String = "--"

    var heartRateAverage: String = "--"
    var heartRateLatest: String = "--"

    // --- HRV split: RMSSD + SDNN ---
    var rmssdAverage: String = "--"
    var rmssdLatest: String = "--"
    var rmssdTimestamp: String = ""

    // Track when RMSSD was last updated
    var lastRmssdUpdate: Date?

    var sdnnAverage: String = "--"
    var sdnnLatest: String = "--"
    var sdnnTimestamp: String = ""

    // Track when SDNN was last updated
    var lastSdnnUpdate: Date?

    var restingHeartRateAverage: String = "--"
    var restingHeartRateLatest: String = "--"
    var restingHeartRateTimestamp: String = ""

    // Track when Resting HR was last updated
    var lastRhrUpdate: Date?

    var sleepTotal: String = "--"
    var sleepDate: String = ""

    var stepsWeeklyAverage: String = "--"
    var stepsToday: String = "--"
    var stepsDate: String = ""

    // Check if RMSSD data is stale (older than 1 hour)
    var isRmssdDataStale: Bool {
        guard let lastUpdate = lastRmssdUpdate else { return true }
        return Date().timeIntervalSince(lastUpdate) > 3600 // 1 hour threshold
    }

    // Check if SDNN data is stale (older than 1 hour)
    var isSdnnDataStale: Bool {
        guard let lastUpdate = lastSdnnUpdate else { return true }
        return Date().timeIntervalSince(lastUpdate) > 3600 // 1 hour threshold
    }
}
