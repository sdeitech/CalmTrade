//
//  StepsSwiftChartView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 12/09/25.
//


import SwiftUI
import Charts

public struct StepBar: Identifiable, Hashable {
    public let id = UUID()
    public let time: Date
    public let value: Double
}

public enum StepsChartRange: CaseIterable { case daily, weekly, monthly }

/// Health-style Steps bar chart (orange bars, dashed grid, trailing Y axis)
public struct StepsSwiftChartView: View {
    public let bars: [StepBar]
    public let range: StepsChartRange
    public let xDomain: ClosedRange<Date>
    /// Max value used to compute the top of Y-axis. Pass raw max; we round to 5k steps.
    public let yMax: Double
    public var color: Color = Color(red: 1.0, green: 0.44, blue: 0.0) // Health orange

    public init(
        bars: [StepBar],
        range: StepsChartRange,
        xDomain: ClosedRange<Date>,
        yMax: Double,
        color: Color = Color(red: 1.0, green: 0.44, blue: 0.0)
    ) {
        self.bars = bars
        self.range = range
        self.xDomain = xDomain
        self.yMax = yMax
        self.color = color
    }

    public var body: some View {
        Chart {
            // vertical dashed grid rules (like Health)
            ForEach(ruleDates, id: \.self) { d in
                RuleMark(x: .value("Rule", d))
                    .foregroundStyle(.white.opacity(0.18))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
            }

            // Bars
            ForEach(bars) { b in
                BarMark(
                    x: .value("Time", b.time),
                    y: .value("Steps", b.value)
                )
                .foregroundStyle(color)
                .cornerRadius(3)
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: 0...roundedYMax)
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
            // Fri • Sat • Sun • Mon • Tue • Wed • Thu (depends on user calendar)
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.18))
                AxisTick().foregroundStyle(.white.opacity(0.35))
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    .foregroundStyle(.white.opacity(0.8))
            }
        case .monthly:
            // Week-of-month labels
            AxisMarks(values: .stride(by: .weekOfYear)) { v in
                AxisGridLine().foregroundStyle(.white.opacity(0.18))
                AxisTick().foregroundStyle(.white.opacity(0.35))
                AxisValueLabel {
                    if let d = v.as(Date.self) {
                        Text("W\(Calendar.current.component(.weekOfMonth, from: d))")
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
    private var roundedYMax: Double {
        // Round up to nearest 5,000 like Health’s 0…15,000 look
        let step = 5_000.0
        return max(step, ceil(yMax / step) * step)
    }

    private var yTicks: [Double] {
        // 0 • mid • top (sparse like Health)
        let top = roundedYMax
        return [0, top / 2.0, top]
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
        var out: [Date] = []
        let start = cal.dateInterval(of: component, for: xDomain.lowerBound)?.start ?? xDomain.lowerBound
        var d = start
        while d <= xDomain.upperBound {
            out.append(d)
            d = cal.date(byAdding: component, value: count, to: d) ?? xDomain.upperBound.addingTimeInterval(1)
        }
        return out
    }
}

#Preview("Steps – Weekly") {
    let cal = Calendar.current
    let end = cal.startOfDay(for: Date())
    let start = cal.date(byAdding: .day, value: -6, to: end)! // 7 days window
    let domain = start...end

    let pts: [StepBar] = (0..<7).map { i in
        .init(time: cal.date(byAdding: .day, value: i, to: start)!, value: [2300, 1800, 1600, 400, 11200, 2400, 2600][i])
    }

    StepsSwiftChartView(
        bars: pts,
        range: .weekly,
        xDomain: domain,
        yMax: pts.map(\.value).max() ?? 0
    )
    .frame(height: 260)
    .preferredColorScheme(.dark)
}
