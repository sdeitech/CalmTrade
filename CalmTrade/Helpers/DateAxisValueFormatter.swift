//
//  DateAxisValueFormatter.swift
//  CalmTrade
//
//  Created by Anas Parekh on 05/09/25.
//


import Foundation
import Charts

/// A custom formatter for the chart's X-axis that displays dates and times intelligently
/// based on the visible range of the data.
//class DateAxisValueFormatter: NSObject, AxisValueFormatter {
//    
//    private let dateFormatter = DateFormatter()
//    
//    override init() {
//        super.init()
//    }
//    
//    public func stringForValue(_ value: Double, axis: AxisBase?) -> String {
//        guard let axis = axis else { return "" }
//        
//        let date = Date(timeIntervalSince1970: value)
//        
//        // Calculate the total visible time span on the chart
//        let visibleTimeSpan = axis.axisMaximum - axis.axisMinimum
//        
//        // Adjust the date format based on the visible time span
//        if visibleTimeSpan > TimeInterval(3600 * 24 * 30 * 6) { // > ~6 months
//            dateFormatter.dateFormat = "MMM ''yy" // e.g., "Jan '25"
//        } else if visibleTimeSpan > TimeInterval(3600 * 24 * 7) { // > 1 week
//            dateFormatter.dateFormat = "MMM d" // e.g., "Sep 5"
//        } else if visibleTimeSpan > TimeInterval(3600 * 3) { // > 3 hours
//            dateFormatter.dateFormat = "h a" // e.g., "3 PM"
//        } else {
//            dateFormatter.dateFormat = "h:mm a" // e.g., "3:14 PM"
//        }
//        
//        return dateFormatter.string(from: date)
//    }
//}



