//
//  SleepUIData.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/09/25.
//


import Foundation
import SwiftUI

/// A struct to hold all the processed and formatted data for the Sleep Insight screen.
struct SleepUIData {
    let timeAsleepAttributedText: NSAttributedString
    let sleepDate: String
    let sleepSegments: [SleepSegment]
    let chartStartDate: Date?
    let chartEndDate: Date?
    
    let awakeSeconds: TimeInterval
    let remSeconds: TimeInterval
    let coreSeconds: TimeInterval
    let deepSeconds: TimeInterval
}
