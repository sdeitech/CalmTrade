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
    
    var sdnnAverage: String = "--"
    var sdnnLatest: String = "--"
    var sdnnTimestamp: String = ""
    
    var restingHeartRateAverage: String = "--"
    var restingHeartRateLatest: String = "--"
    var restingHeartRateTimestamp: String = ""
    
    var sleepTotal: String = "--"
    var sleepDate: String = ""
    
    var stepsWeeklyAverage: String = "--"
    var stepsToday: String = "--"
    var stepsDate: String = ""
}
