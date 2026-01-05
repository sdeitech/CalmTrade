//
//  CalmGraphPoint.swift
//  CalmTrade
//
//  Created by Anas Parekh on 11/09/25.
//


import Foundation

struct CalmHistoryItem: Hashable {
    let id = UUID()
    let day: Date
    let average: Double
    var title: String { // Yesterday / 5 June 2025 etc.
        let cal = Calendar.current
        if cal.isDateInYesterday(day) { return "Yesterday" }
        if cal.isDateInToday(day)     { return "Today" }
        let df = DateFormatter()
        df.dateFormat = "d MMMM yyyy"
        return df.string(from: day)
    }
}
