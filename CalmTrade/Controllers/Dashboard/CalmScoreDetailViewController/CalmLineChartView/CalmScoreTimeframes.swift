//
//  CalmScoreTimeframes.swift
//  CalmTrade
//

import SwiftUI
import Foundation

// MARK: - Helpers

@inline(__always)
private func dynamicYMax(from uppers: [Double]) -> Double {
    let maxU = uppers.max() ?? 0
    let rounded = Double((Int(ceil(maxU / 20.0)) * 20))
    return min(100, max(20, rounded))
}

@inline(__always)
private func filledCountForTrailingZeros(_ ranges: [ClosedRange<Double>]) -> Int {
    // find last index that is NOT 0...0
    if let lastIdx = ranges.lastIndex(where: { !($0.lowerBound == 0 && $0.upperBound == 0) }) {
        return lastIdx + 1
    }
    return 0
}

@inline(__always)
private func mapToOptionalSlots(_ ranges: [ClosedRange<Double>], filledCount: Int) -> [ClosedRange<Double>?] {
    ranges.enumerated().map { idx, r in
        idx < filledCount ? r : nil
    }
}

// MARK: - HOUR (already working the way you want)

public struct HourChartView: View {
    public let ranges: [ClosedRange<Double>?]  // from VM: 20 items at 3m
    public let startOfHour: Date
    public let bucketMinutes: Int              // 3
    public let filledCount: Int
    
    public init(ranges: [ClosedRange<Double>?],
                startOfHour: Date,
                bucketMinutes: Int = 3,
                filledCount: Int) {
        self.ranges = ranges
        self.startOfHour = startOfHour
        self.bucketMinutes = bucketMinutes
        self.filledCount = filledCount
    }
    
    private var timeCap: Int {
        let cal = Calendar.current
        let now = Date()
        let endOfHour = cal.date(byAdding: .hour, value: 1, to: startOfHour)!
        
        if now <= startOfHour { return 0 }                  // future hour
        if now >= endOfHour { return ranges.count }         // past/completed hour
        
        let mins = cal.dateComponents([.minute], from: startOfHour, to: now).minute ?? 0
        // number of buckets that have *started*
        return min(ranges.count, Int(floor(Double(mins) / Double(max(1, bucketMinutes)))) + 1)
    }
    
    private var effectiveFilled: Int { min(filledCount, timeCap) }
    
    private var yMax: Double {
        let visible = ranges.prefix(effectiveFilled).compactMap { $0?.upperBound }
        return dynamicYMax(from: visible)
    }
    
    public var body: some View {
        CalmScoreRangeChart(
            slots: makeSlots(),
            spacing: 5,
            labelEvery: 1,
            showYAxisMarks: true,
            axisWidth: 36,
            axisGutter: 8,
            yMax: yMax,
            yStep: 20,
            filledCount: effectiveFilled   // << use the time-capped count
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func makeSlots() -> [CalmScoreRangeSlot] {
        let cal = Calendar.current
        let count = ranges.count
        
        // Map 0/15/30/45 minutes to bucket indices (works for any bucketMinutes, incl. 3m).
        let tickMinutes = [0, 15, 30, 45]
        let labelIndices: Set<Int> = Set(
            tickMinutes.map { m in
                min(count - 1, Int(round(Double(m) / Double(max(1, bucketMinutes)))))
            }
        )
        
        // Match HR chart formatters.
        let dfHour = DateFormatter.cached("h")
        let dfHM   = DateFormatter.cached("h:mm a")
        
        return (0..<count).map { i in
            let slotStart = cal.date(byAdding: .minute, value: i * bucketMinutes, to: startOfHour) ?? startOfHour
            let label: String? = labelIndices.contains(i)
            ? (i == 0 ? dfHour.string(from: slotStart) : dfHM.string(from: slotStart))
            : nil
            return CalmScoreRangeSlot(range: ranges[i], bottomLabel: label)
        }
    }
}

// MARK: - DAY (24 hours, labels at 12/6/12/6)

public struct DayChartView: View {
    let hourly: [ClosedRange<Double>]   // may contain trailing 0...0 (no data)
    let anchor: Date
    
    public init(hourlyRanges: [ClosedRange<Double>], anchor: Date = Date()) {
        self.hourly = hourlyRanges
        self.anchor = anchor
    }
    
    private var filledCount: Int {
        filledCountForTrailingZeros(hourly)
    }
    
    private var timeCap: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: anchor)
        let end   = cal.date(byAdding: .day, value: 1, to: start)!
        
        let now = Date()
        if now < start { return 0 }             // future day
        if now >= end { return 24 }             // past day (complete)
        
        // current day → hours that have started (0…23) + 1
        return (cal.component(.hour, from: now)) + 1
    }
    
    private var effectiveFilled: Int { min(filledCount, timeCap) }
    
    private var slots: [CalmScoreRangeSlot] {
        let rangesOpt = mapToOptionalSlots(hourly, filledCount: effectiveFilled)
        let cal = Calendar.current
        let start = cal.startOfDay(for: anchor)
        
        let df = DateFormatter.cached("ha")
        df.locale = Locale(identifier: "en_US_POSIX")
        df.amSymbol = "AM"
        df.pmSymbol = "PM"
        
        return (0..<rangesOpt.count).map { i in
            let h = cal.date(byAdding: .hour, value: i, to: start) ?? start
            let label = (i % 6 == 0) ? df.string(from: h) : ""
            return .init(range: rangesOpt[i], bottomLabel: label)
        }
    }
    
    private var yMax: Double {
        let uppers = hourly.prefix(effectiveFilled).map { $0.upperBound }
        return dynamicYMax(from: uppers)
    }
    
    public var body: some View {
        CalmScoreRangeChart(
            slots: slots,
            spacing: 6,
            labelEvery: 1,
            showYAxisMarks: true,
            axisWidth: 36,
            axisGutter: 8,
            yMax: yMax,
            yStep: 20,
            filledCount: filledCount
        )
    }
}

// MARK: - WEEK (7 days, Sun→Sat)

public struct WeekChartView: View {
    let rangesIn: [ClosedRange<Double>]   // trailing 0...0 → future
    let weekAnchor: Date                  // any date within the target week
    
    
    public init(_ ranges: [ClosedRange<Double>], weekAnchor: Date = Date()) {
        self.rangesIn = ranges
        self.weekAnchor = weekAnchor
    }
    
    private var filledCount: Int {
        filledCountForTrailingZeros(rangesIn)
    }
    
    private var timeCap: Int {
        let cal = Calendar.current
        // Start of the anchored week (Sunday-based; adjust if you prefer Monday)
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekAnchor)
        let startOfWeek = cal.date(from: comps) ?? weekAnchor
        let endOfWeek = cal.date(byAdding: .day, value: 7, to: startOfWeek)!
        
        let now = Date()
        if now < startOfWeek { return 0 }          // future week
        if now >= endOfWeek { return 7 }           // past week (complete)
        
        // index within the week 0…6 (Sunday==0). Show up to *today* inclusive.
        let dayIndex = cal.dateComponents([.day], from: startOfWeek, to: now).day ?? 0
        return min(7, dayIndex + 1)
    }
    
    private var dataFilled: Int { filledCountForTrailingZeros(rangesIn) }
    private var effectiveFilled: Int { min(dataFilled, timeCap) }
    
    private var yMax: Double {
        dynamicYMax(from: rangesIn.prefix(effectiveFilled).map { $0.upperBound })
    }
    
    private var slots: [CalmScoreRangeSlot] {
        let symbols = Calendar.current.shortWeekdaySymbols // Sun, Mon, ...
        let opt = mapToOptionalSlots(rangesIn, filledCount: effectiveFilled)
        return (0..<opt.count).map { i in
                .init(range: opt[i], bottomLabel: symbols[i % symbols.count])
        }
    }
    
    public var body: some View {
        CalmScoreRangeChart(
            slots: slots,
            spacing: 14,
            labelEvery: 1,
            showYAxisMarks: true,
            axisWidth: 36,
            axisGutter: 8,
            yMax: yMax,
            yStep: 20,
            filledCount: filledCount
        )
    }
}

// MARK: - MONTH (N days, label every 5th)

public struct MonthChartView: View {
    let dailyIn: [ClosedRange<Double>]
    let monthAnchorDate: Date
    
    public init(dailyRanges: [ClosedRange<Double>], monthAnchorDate: Date) {
        self.dailyIn = dailyRanges
        self.monthAnchorDate = monthAnchorDate
    }
    
    private var filledCount: Int {
        filledCountForTrailingZeros(dailyIn)
    }
    
    private var timeCap: Int {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: monthAnchorDate)) ?? monthAnchorDate
        let range = cal.range(of: .day, in: .month, for: start)!
        let daysInMonth = range.count
        let end = cal.date(byAdding: .month, value: 1, to: start)!
        
        let now = Date()
        if now < start { return 0 }                          // future month
        if now >= end { return min(dailyIn.count, daysInMonth) } // past month complete
        
        // current month → 1…daysInMonth (today inclusive)
        let day = cal.component(.day, from: now)
        return min(dailyIn.count, day)
    }
    
    private var dataFilled: Int { filledCountForTrailingZeros(dailyIn) }
    private var effectiveFilled: Int { min(dataFilled, timeCap) }
    
    private var slots: [CalmScoreRangeSlot] {
        let opt = mapToOptionalSlots(dailyIn, filledCount: effectiveFilled)
        
        let cal = Calendar.current
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: monthAnchorDate)) ?? monthAnchorDate
        let df = DateFormatter(); df.dateFormat = "d"
        
        return (0..<opt.count).map { i in
            let d = cal.date(byAdding: .day, value: i, to: startOfMonth) ?? startOfMonth
            let label = (i % 5 == 0) ? df.string(from: d) : ""
            return .init(range: opt[i], bottomLabel: label)
        }
    }
    
    private var yMax: Double {
        dynamicYMax(from: dailyIn.prefix(effectiveFilled).map { $0.upperBound })
    }
    
    
    public var body: some View {
        CalmScoreRangeChart(
            slots: slots,
            spacing: 6,
            labelEvery: 1,
            showYAxisMarks: true,
            axisWidth: 36,
            axisGutter: 8,
            yMax: yMax,
            yStep: 20,
            filledCount: filledCount
        )
    }
}

// MARK: - YEAR (12 months, Jan…Dec)

public struct YearChartView: View {
    let monthlyIn: [ClosedRange<Double>]
    
    public init(_ monthlyRanges: [ClosedRange<Double>]) {
        self.monthlyIn = monthlyRanges
    }
    
    private var filledCount: Int {
        filledCountForTrailingZeros(monthlyIn)
    }
    
    private var yMax: Double {
        dynamicYMax(from: monthlyIn.prefix(filledCount).map { $0.upperBound })
    }
    
    private var slots: [CalmScoreRangeSlot] {
        let labels = Calendar.current.shortMonthSymbols
        let opt = mapToOptionalSlots(monthlyIn, filledCount: filledCount)
        return (0..<opt.count).map { i in
                .init(range: opt[i], bottomLabel: labels[i % labels.count].first?.uppercased())
        }
    }
    
    public var body: some View {
        CalmScoreRangeChart(
            slots: slots,
            spacing: 10,
            labelEvery: 1,
            showYAxisMarks: true,
            axisWidth: 36,
            axisGutter: 8,
            yMax: yMax,
            yStep: 20,
            filledCount: filledCount
        )
    }
}


// MARK: - Previews
private enum _TFDemo {
    static func ranges(count: Int, center: ClosedRange<Double> = 30...80, jitter: Double = 8) -> [ClosedRange<Double>] {
        guard count > 0 else { return [] }
        return (0..<count).map { i in
            let phase = Double(i) / Double(max(1, count - 1))
            let mid = center.lowerBound + (center.upperBound - center.lowerBound) * (0.5 + 0.35 * sin(phase * .pi * 2))
            let lo = max(0, mid - jitter)
            let hi = min(100, mid + jitter * (0.6 + 0.4 * cos(phase * .pi * 2)))
            return lo...max(lo + 1, hi)
        }
    }
}

struct CalmScoreTimeframes_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // HOUR: 60 minutes, labels every 5 min
            HourChartView(
                ranges: _TFDemo.ranges(count: 60, center: 40...85, jitter: 6),
                startOfHour: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!, filledCount: 7
            )
            .frame(height: 260)
            .padding()
            .background(Color.black)
            .previewDisplayName("Hour (60 slots)")
            
            // DAY: 24 hours
            DayChartView(
                hourlyRanges: _TFDemo.ranges(count: 24, center: 35...80, jitter: 7),
                anchor: Date()
            )
            .frame(height: 260)
            .padding()
            .background(Color.black)
            .previewDisplayName("Day (24 slots)")
            
            // WEEK: 7 days (Sun→Sat)
            WeekChartView(_TFDemo.ranges(count: 7, center: 30...85, jitter: 9))
                .frame(height: 260)
                .padding()
                .background(Color.black)
                .previewDisplayName("Week (7 slots)")
            
            // MONTH: number of days in anchor month (use current month)
            MonthChartView(
                dailyRanges: {
                    let cal = Calendar.current
                    let anchor = Date()
                    let days = cal.range(of: .day, in: .month, for: anchor)?.count ?? 30
                    return _TFDemo.ranges(count: days, center: 30...85, jitter: 7)
                }(),
                monthAnchorDate: Date()
            )
            .frame(height: 260)
            .padding()
            .background(Color.black)
            .previewDisplayName("Month (N days)")
            
            // YEAR: 12 months
            YearChartView(_TFDemo.ranges(count: 12, center: 25...90, jitter: 8))
                .frame(height: 260)
                .padding()
                .background(Color.black)
                .previewDisplayName("Year (12 months)")
        }
        .preferredColorScheme(.dark)
    }
}

private extension DateFormatter {
    static func cached(_ fmt: String) -> DateFormatter {
        struct Store { static var cache: [String: DateFormatter] = [:] }
        if let f = Store.cache[fmt] { return f }
        let f = DateFormatter(); f.dateFormat = fmt; Store.cache[fmt] = f; return f
    }
}
