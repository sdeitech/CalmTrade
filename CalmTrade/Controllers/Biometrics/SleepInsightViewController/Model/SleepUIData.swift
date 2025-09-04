//
//  SleepUIData.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/09/25.
//


import UIKit
import Charts

/// A struct to hold all the processed and formatted data for the Sleep Insight screen.
struct SleepUIData {
    let chartData: BarChartData
    let timeAsleepAttributedText: NSAttributedString
    let sleepDate: String
    let xAxisLabels: [String]
    let xAxisValues: [Double]
}

