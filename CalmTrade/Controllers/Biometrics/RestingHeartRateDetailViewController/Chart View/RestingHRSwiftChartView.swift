//
//  RestingHRSwiftChartView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 12/09/25.
//

import SwiftUI
import Charts

// MARK: - Model used by the chart
public struct RestingHRPoint: Identifiable, Hashable {
    public let id = UUID()
    public let time: Date
    public let value: Double
}

public enum RHRChartRange: CaseIterable { case daily, weekly, monthly }

/// SwiftUI replica of the iOS Health "Resting Heart Rate" chart
public struct RestingHRSwiftChartView: View {
    public let points: [RestingHRPoint]
    public let range: RHRChartRange
    public let xDomain: ClosedRange<Date>
    /// Pass the max value from the VM; view rounds to nearest 10
    public let yMax: Double
    public var color: Color = Color(red: 1.00, green: 0.31, blue: 0.49) // Health pink

    public init(points: [RestingHRPoint],
                range: RHRChartRange,
                xDomain: ClosedRange<Date>,
                yMax: Double,
                color: Color = Color(red: 1.00, green: 0.31, blue: 0.49)) {
        self.points = points
        self.range = range
        self.xDomain = xDomain
        self.yMax = yMax
        self.color = color
    }

    public var body: some View {
        // Single Chart ONLY. (If you ever see two, you’ve added two Chart{} blocks.)
        Chart {
            // Vertical grid/rule style like Health
            ForEach(ruleDates, id: \.self) { d in
                RuleMark(x: .value("Rule", d))
                    .foregroundStyle(.white.opacity(0.18))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
            }

            // Line (monotone) with rounded joins
            ForEach(points) { p in
                LineMark(
                    x: .value("Time", p.time),
                    y: .value("BPM", p.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

            // Dots on samples (Health shows circles)
            ForEach(points) { p in
                PointMark(
                    x: .value("Time", p.time),
                    y: .value("BPM", p.value)
                )
                .symbol(Circle())
                .symbolSize(36)
                .foregroundStyle(color)
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yDomain)
        .chartXAxis { xAxis }
        .chartYAxis { yAxis }
        .chartPlotStyle { plot in
//            plot.background(.clear)
            plot.border(.white.opacity(0.18), width: 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 220)
        .background(Color.black)
    }

    // MARK: - Axes

    @AxisContentBuilder
    private var xAxis: some AxisContent {
        switch range {
        case .daily:
            // 12 AM • 6 AM • 12 PM • 6 PM
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.18))
                AxisTick().foregroundStyle(.white.opacity(0.35))
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                    .foregroundStyle(.white.opacity(0.8))
            }
        case .weekly:
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.18))
                AxisTick().foregroundStyle(.white.opacity(0.35))
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    .foregroundStyle(.white.opacity(0.8))
            }
        case .monthly:
            AxisMarks(values: .stride(by: .weekOfYear)) { v in
                AxisGridLine().foregroundStyle(.white.opacity(0.18))
                AxisTick().foregroundStyle(.white.opacity(0.35))
                AxisValueLabel {
                    if let d = v.as(Date.self) {
                        Text(weekOfMonthString(for: d))
                    }
                }
                .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    @AxisContentBuilder
    private var yAxis: some AxisContent {
        AxisMarks(position: .trailing, values: yTicks) { _ in
            AxisGridLine().foregroundStyle(.white.opacity(0.18))
            AxisTick().foregroundStyle(.white.opacity(0.35))
            AxisValueLabel().foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Helpers

    // Health tends to show a tight 2-tick range (e.g., 100 & 120).
    private var yDomain: ClosedRange<Double> {
        let top = ceil(yMax / 10.0) * 10.0
        let bottom = max(30.0, floor((points.map(\.value).min() ?? 30) / 10.0) * 10.0)
        return bottom ... max(bottom + 10, top)
    }

    private var yTicks: [Double] {
        let lo = yDomain.lowerBound
        let hi = yDomain.upperBound
        // two labels (lower & upper), like Health’s sparse scale
        return [lo, hi]
    }

    private var ruleDates: [Date] {
        switch range {
        case .daily:   return strideDates(by: .hour, count: 6)
        case .weekly:  return strideDates(by: .day, count: 1)
        case .monthly: return strideDates(by: .weekOfYear, count: 1)
        }
    }

    private func strideDates(by component: Calendar.Component, count: Int) -> [Date] {
        let cal = Calendar.current
        guard xDomain.lowerBound < xDomain.upperBound else { return [] }
        let start = cal.dateInterval(of: component, for: xDomain.lowerBound)?.start ?? xDomain.lowerBound
        var d = start
        var out: [Date] = []
        while d <= xDomain.upperBound {
            out.append(d)
            d = cal.date(byAdding: component, value: count, to: d) ?? xDomain.upperBound.addingTimeInterval(1)
        }
        return out
    }

    private func weekOfMonthString(for date: Date) -> String {
        "W\(Calendar.current.component(.weekOfMonth, from: date))"
    }
}

// MARK: - Preview (single chart)
#Preview("Resting HR – Weekly") {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let start = cal.date(byAdding: .day, value: -6, to: today)!
    let end   = cal.date(byAdding: .day, value: 1, to: today)!
    let domain = start...end

    let pts: [RestingHRPoint] = [
        .init(time: cal.date(byAdding: .day, value: -6, to: today)!, value: 110),
        .init(time: cal.date(byAdding: .day, value: -5, to: today)!, value: 100),
        .init(time: cal.date(byAdding: .day, value: -4, to: today)!, value: 90)
    ]

    return RestingHRSwiftChartView(points: pts,
                                   range: .weekly,
                                   xDomain: domain,
                                   yMax: pts.map(\.value).max() ?? 0)
        .frame(height: 260)
        .preferredColorScheme(.dark)
}
