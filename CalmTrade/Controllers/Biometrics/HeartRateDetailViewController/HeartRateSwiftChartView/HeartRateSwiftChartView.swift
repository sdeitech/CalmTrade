//
//  HeartRateSwiftChartView.swift
//  CalmTrade
//
//  Health-style HR chart: neutral baseline + red-on-select highlight
//  - Accepts explicit xDomain & xAxisTicks so the X-axis never collapses to a single label
//  - Draws neutral baseline bars/dots and paints only the selected bucket in red
//

import SwiftUI
import Charts

// HeartPoint convenience
extension HeartPoint {
    var mid: Double { (min + max) / 2 }
}

@available(iOS 16.0, *)
struct HeartRateSwiftChartView: View {

    // MARK: - Inputs
    public var points: [HeartPoint]

    /// Neutral baseline color for all bars/dots (e.g. Health’s gray/white)
    public var baseColor: Color = .white.opacity(0.45)
    /// Emphasis color for the *selected* time only (Health’s red)
    public var selectionColor: Color = .red

    public var showMidpointDot: Bool = true
    public var showVerticalRules: Bool = true
    public var yDomain: ClosedRange<Double>? = nil
    public var approxRuleCount: Int = 6
    public var enableSelection: Bool = true

    /// Explicit X scale domain and tick values (supplied by the view model)
    public var xDomain: ClosedRange<Date>
    public var xAxisTicks: [Date]
    public var xLabelFormat: Date.FormatStyle

    @State private var selected: HeartPoint?

    public init(points: [HeartPoint],
                xDomain: ClosedRange<Date>,
                xAxisTicks: [Date],
                xLabelFormat: Date.FormatStyle,
                baseColor: Color = .white.opacity(0.45),
                selectionColor: Color = .red,
                showMidpointDot: Bool = true,
                showVerticalRules: Bool = true,
                yDomain: ClosedRange<Double>? = nil,
                approxRuleCount: Int = 6,
                enableSelection: Bool = true) {
        self.points = points
        self.xDomain = xDomain
        self.xAxisTicks = xAxisTicks
        self.xLabelFormat = xLabelFormat
        self.baseColor = baseColor
        self.selectionColor = selectionColor
        self.showMidpointDot = showMidpointDot
        self.showVerticalRules = showVerticalRules
        self.yDomain = yDomain
        self.approxRuleCount = approxRuleCount
        self.enableSelection = enableSelection
    }

    // MARK: - Body
    public var body: some View {
        chartCore
            .chartXScale(domain: xDomain)
            .applyYDomain(resolvedYDomain)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.18))
                    AxisTick().foregroundStyle(.white.opacity(0.35))
                    AxisValueLabel(format: xLabelFormat)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: yTicks) { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.18))
                    AxisTick().foregroundStyle(.white.opacity(0.35))
                    AxisValueLabel().foregroundStyle(.white.opacity(0.7))
                }
            }
            .chartOverlay { proxy in overlay(proxy: proxy) }
            .background(Color.black)
            .frame(minHeight: 220)
    }

    // MARK: - Chart content
    private var chartCore: some View {
        Chart {
            if showVerticalRules { verticalRuleMarks }
            baselineBars
            if showMidpointDot { baselineMidpointDots }
            // Draw selection highlight *over* baseline so it appears in red only when selected
            selectionHighlight
            selectionCrosshair
        }
    }

    // Dotted vertical rules aligned to provided tick values
    @ChartContentBuilder
    private var verticalRuleMarks: some ChartContent {
        ForEach(xAxisTicks, id: \.timeIntervalSince1970) { t in
            RuleMark(x: .value("Rule", t))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 5]))
                .foregroundStyle(.white.opacity(0.18))
        }
    }

    // Neutral min–max bars (baseline)
    @ChartContentBuilder
    private var baselineBars: some ChartContent {
        ForEach(points, id: \.time) { p in
            if #available(iOS 17.0, *) {
                BarMark(
                    x: .value("Time", p.time),
                    yStart: .value("Min", p.min),
                    yEnd: .value("Max", p.max),
                    width: .fixed(8)
                )
                .foregroundStyle(baseColor)
                .cornerRadius(5)
            } else {
                BarMark(
                    x: .value("Time", p.time),
                    yStart: .value("Min", p.min),
                    yEnd: .value("Max", p.max)
                )
                .foregroundStyle(baseColor)
                .cornerRadius(5)
            }
        }
    }

    // Neutral midpoint dots (baseline)
    @ChartContentBuilder
    private var baselineMidpointDots: some ChartContent {
        ForEach(points, id: \.time) { p in
            PointMark(
                x: .value("Time", p.time),
                y: .value("Mid", p.mid)
            )
            .symbolSize(30)
            .foregroundStyle(baseColor)
        }
    }

    // Red highlight for the *selected* bucket only
    @ChartContentBuilder
    private var selectionHighlight: some ChartContent {
        if enableSelection, let s = selected {
            if #available(iOS 17.0, *) {
                BarMark(
                    x: .value("Selected Time", s.time),
                    yStart: .value("Min", s.min),
                    yEnd: .value("Max", s.max),
                    width: .fixed(10)
                )
                .foregroundStyle(selectionColor)
                .cornerRadius(5)
            } else {
                BarMark(
                    x: .value("Selected Time", s.time),
                    yStart: .value("Min", s.min),
                    yEnd: .value("Max", s.max)
                )
                .foregroundStyle(selectionColor)
                .cornerRadius(5)
            }
        }
    }

    // Crosshair + bubble (only when selected)
    @ChartContentBuilder
    private var selectionCrosshair: some ChartContent {
        if enableSelection, let s = selected {
            RuleMark(x: .value("Selected", s.time))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 6]))
                .foregroundStyle(.white.opacity(0.6))
                .annotation(position: .topLeading, spacing: 0) {
                    Text("\(Int(s.mid))")
                        .font(.headline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThickMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
        }
    }

    // MARK: - Overlay (drag to select)
    @ViewBuilder
    private func overlay(proxy: ChartProxy) -> some View {
        if enableSelection {
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { g in
                                let frame = geo[proxy.plotAreaFrame]
                                let x = g.location.x - frame.origin.x
                                guard x >= 0, let date: Date = proxy.value(atX: x) else { return }
                                if let nearest = nearestPoint(to: date) { selected = nearest }
                            }
                    )
                    .onTapGesture { selected = nil } // tap to clear selection (back to neutral)
            }
        }
    }

    // MARK: - Layout helpers
    private var resolvedYDomain: ClosedRange<Double> {
        if let d = yDomain { return d }
        let vals = points.flatMap { [$0.min, $0.max] }
        let lo = max(0, floor((vals.min() ?? 0) / 10) * 10)
        let hiRaw = ceil((vals.max() ?? 100) / 10) * 10
        let hi = max(100, hiRaw)
        let snappedHi = max(100, (ceil(hi / 50) * 50))
        return 0...snappedHi
    }

    private var yTicks: [Double] {
        let observedMax = points.map(\.max).max() ?? 0
        let paddedTop   = max(100.0, ceil((observedMax * 1.1) / 50.0) * 50.0)
        if paddedTop <= 100 {
            return [0.0, 50.0, paddedTop]
        } else {
            let mid = (floor(paddedTop / 100.0) * 100.0) / 2.0
            return [0.0, mid, paddedTop]
        }
    }

    private func nearestPoint(to date: Date) -> HeartPoint? {
        guard !points.isEmpty else { return nil }
        var best = points[0]
        var bestDelta = abs(best.time.timeIntervalSince(date))
        for p in points.dropFirst() {
            let d = abs(p.time.timeIntervalSince(date))
            if d < bestDelta { bestDelta = d; best = p }
        }
        return best
    }
}

// MARK: - Lightweight modifiers
@available(iOS 16.0, *)
private struct YDomainModifier: ViewModifier {
    let domain: ClosedRange<Double>
    func body(content: Content) -> some View { content.chartYScale(domain: domain) }
}

@available(iOS 16.0, *)
private extension View {
    func applyYDomain(_ domain: ClosedRange<Double>) -> some View { modifier(YDomainModifier(domain: domain)) }
}

@available(iOS 16.0, *)
#Preview("Health-style HR • Dark") {
    // Simple preview with deterministic hourly ticks
    let cal = Calendar.current
    let base = cal.startOfDay(for: Date())
    let pts: [HeartPoint] = (0..<24).map { i in
        let t = cal.date(byAdding: .hour, value: i, to: base)!
        let low = Double(60 + Int.random(in: 0...20))
        let high = low + Double(Int.random(in: 10...40))
        return .init(time: t, min: low, max: high)
    }
    let domain = base ... cal.date(byAdding: .hour, value: 23, to: base)!
    var ticks: [Date] = []
    for i in 0..<24 { ticks.append(cal.date(byAdding: .hour, value: i, to: base)!) }

    return HeartRateSwiftChartView(
        points: pts,
        xDomain: domain,
        xAxisTicks: ticks,
        xLabelFormat: .dateTime.hour(),
        enableSelection: true
    )
    .preferredColorScheme(.dark)
    .frame(height: 260)
    .padding()
    .background(Color.black)
}
