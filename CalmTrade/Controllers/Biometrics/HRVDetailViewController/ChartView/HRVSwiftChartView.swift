//
//  HRVSwiftChartView.swift
//  CalmTrade
//

import SwiftUI
import Charts

public struct HRVPoint: Identifiable, Hashable {
    public let id = UUID()
    public let time: Date
    public let value: Double
}

public enum HRVChartRange: CaseIterable { case daily, weekly, monthly }

public struct HRVSwiftChartView: View {
    public let points: [HRVPoint]
    public let range: HRVChartRange
    public let xDomain: ClosedRange<Date>
    public let yMax: Double
    public var color: Color = Color(red: 1.0, green: 0.31, blue: 0.49)

    public init(points: [HRVPoint],
                range: HRVChartRange,
                xDomain: ClosedRange<Date>,
                yMax: Double,
                color: Color = Color(red: 1.0, green: 0.31, blue: 0.49)) {
        self.points = points
        self.range = range
        self.xDomain = xDomain
        self.yMax = yMax
        self.color = color
    }

    public var body: some View {
        Chart {
            // dashed vertical grid rules (single plot)
            ForEach(ruleDates, id: \.self) { d in
                RuleMark(x: .value("Rule", d))
                    .foregroundStyle(.white.opacity(0.18))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
            }

            // ONE series: line + points
            ForEach(points) { p in
                LineMark(
                    x: .value("Time", p.time),
                    y: .value("ms", p.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Time", p.time),
                    y: .value("ms", p.value)
                )
                .symbol(Circle())
                .symbolSize(36)
                .foregroundStyle(color)
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: 0...roundedYMax(yMax))
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

    // MARK: Axes

    @AxisContentBuilder
    private var xAxis: some AxisContent {
        switch range {
        case .daily:
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

    // MARK: Helpers

    private func roundedYMax(_ v: Double) -> Double {
        let step = 200.0
        return max(step, ceil(v / step) * step)
    }

    private var yTicks: [Double] {
        let top = roundedYMax(yMax)
        return [0, (top / 2.0).rounded(), top]
    }

    private var ruleDates: [Date] {
        switch range {
        case .daily:   return strideDates(by: .hour,      count: 6)
        case .weekly:  return strideDates(by: .day,       count: 1)
        case .monthly: return strideDates(by: .weekOfYear,count: 1)
        }
    }

    private func strideDates(by component: Calendar.Component, count: Int) -> [Date] {
        let cal = Calendar.current
        var out: [Date] = []
        // snap to component boundary for clean vertical rules
        let start = cal.dateInterval(of: component, for: xDomain.lowerBound)?.start ?? xDomain.lowerBound
        var d = start
        while d <= xDomain.upperBound {
            out.append(d)
            d = cal.date(byAdding: component, value: count, to: d) ?? xDomain.upperBound.addingTimeInterval(1)
        }
        return out
    }

    private func weekOfMonthString(for date: Date) -> String {
        let week = Calendar.current.component(.weekOfMonth, from: date)
        return "W\(week)"
    }
}

#Preview("HRV – Daily (single)") {
    let cal = Calendar.current
    let start = cal.startOfDay(for: Date())
    let end   = cal.date(byAdding: .day, value: 1, to: start)!
    let domain = start...end

    let pts: [HRVPoint] = [
        HRVPoint(time: cal.date(byAdding: .hour, value: 11, to: start)!, value: 52),
        HRVPoint(time: cal.date(byAdding: .hour, value: 12, to: start)!, value: 48),
        HRVPoint(time: cal.date(byAdding: .hour, value: 13, to: start)!, value: 46),
        HRVPoint(time: cal.date(byAdding: .hour, value: 17, to: start)!, value: 510),
    ]

    HRVSwiftChartView(points: pts, range: .weekly, xDomain: domain, yMax: pts.map(\.value).max() ?? 0)
        .frame(height: 260)
        .preferredColorScheme(.dark)
}
