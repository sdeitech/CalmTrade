//
//  HeartRateCalmChartView.swift
//  CalmTrade
//
//  CalmScore-style range chart for Heart Rate (BPM)
//  - Solid red columns (no gradient), neutral tracks for empty/future
//  - Same layout/timeframe patterns as CalmScoreRangeChart (axis on right, labels at bottom)
//
//  Created by Anas Parekh on 01/10/25.
//

import SwiftUI

// MARK: - Tick picking (no 100-cap; HR can exceed 100)
@inline(__always)
private func hrChooseStepAndTop(rangeMax: Double, maxTicks: Int) -> (step: Double, top: Double) {
    let safeMax = max(0.0, rangeMax)
    let ticks = max(2, maxTicks)
    let raw = (ticks > 0) ? (safeMax / Double(ticks)) : safeMax
    guard raw > 0 else { return (step: 10, top: 50) }

    let exp = floor(log10(raw))
    let base = pow(10.0, exp)
    let frac = raw / base

    let niceFrac: Double
    if frac <= 1 { niceFrac = 1 }
    else if frac <= 2 { niceFrac = 2 }
    else if frac <= 5 { niceFrac = 5 }
    else { niceFrac = 10 }

    let step = niceFrac * base
    let top  = ceil(safeMax / step) * step
    return (step, max(step, top))
}

// MARK: - HR slot (identical semantics as CalmScoreRangeSlot)
struct HeartRateRangeSlot: Identifiable {
    let id = UUID()
    var range: ClosedRange<Double>?
    var bottomLabel: String?

    init(range: ClosedRange<Double>?, bottomLabel: String? = nil) {
        self.range = range
        self.bottomLabel = bottomLabel
    }
}

// MARK: - Right axis (reuse style)
private struct HeartRightAxis: View {
    let yMax: Double
    let step: Double

    private var ticks: [Double] {
        guard yMax > 0, step > 0 else { return [0] }
        let top = max(step, yMax)
        var out: [Double] = []
        var v: Double = 0
        while v <= top + 0.0001 { out.append(v); v += step }
        return out
    }

    @inline(__always) private func pixelAlignedY(_ y: CGFloat, scale: CGFloat) -> CGFloat { (floor(y * scale) + 0.5) / scale }
    @inline(__always) private func yPos(for tick: Double, height h: CGFloat, scale: CGFloat) -> CGFloat {
        let denom = max(yMax, step)
        let frac = CGFloat(min(1, max(0, tick / denom)))
        let baseY = h * (1.0 - frac)
        let adjusted = (tick == 0) ? (h - 0.5 / scale) : baseY
        return pixelAlignedY(adjusted, scale: scale)
    }

    var body: some View {
        GeometryReader { geo in
            let h = max(1, geo.size.height)
            let scale = UIScreen.main.scale
            ZStack(alignment: .topLeading) {
                ForEach(ticks, id: \.self) { t in
                    let y = yPos(for: t, height: h, scale: scale)
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)

                    Text("\(Int(t))")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize()
                        .position(x: geo.size.width - 10, y: y)
                }
            }
        }
    }
}

// MARK: - Core chart (CalmScore look, but solid red ranges)
struct HeartRateRangeChart: View {
    var slots: [HeartRateRangeSlot]

    // Layout / axis
    var spacing: CGFloat = 6
    var labelEvery: Int = 1
    var showYAxisMarks: Bool = true
    var axisWidth: CGFloat = 36
    var axisGutter: CGFloat = 8

    // Dynamic Y
    var yMax: Double
    var yStep: Double = 20

    // Filled vs future
    var filledCount: Int?

    // Color: solid red bars, neutral tracks
    var rangeColor: Color = .red
    var trackColor: Color = .white.opacity(0.08)

    init(slots: [HeartRateRangeSlot],
         spacing: CGFloat = 6,
         labelEvery: Int = 1,
         showYAxisMarks: Bool = true,
         axisWidth: CGFloat = 36,
         axisGutter: CGFloat = 8,
         yMax: Double,
         yStep: Double = 20,
         filledCount: Int? = nil,
         rangeColor: Color = .red) {
        self.slots = slots
        self.spacing = spacing
        self.labelEvery = max(1, labelEvery)
        self.showYAxisMarks = showYAxisMarks
        self.axisWidth = axisWidth
        self.axisGutter = axisGutter
        self.yMax = max(yStep, yMax)
        self.yStep = max(1, yStep)
        self.filledCount = filledCount
        self.rangeColor = rangeColor
    }

    var body: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let totalH = max(1, geo.size.height)

            let labelH: CGFloat = 18
            let trackH = max(1, totalH - labelH)

            // choose a nice step/top for the available pixel height
            let minTickSpacingPx: CGFloat = 22
            let maxTicks = Int(floor(trackH / max(1, minTickSpacingPx)))
            let picked = hrChooseStepAndTop(rangeMax: yMax, maxTicks: maxTicks)
            let displayStep = max(1, picked.step)
            let displayTop  = max(displayStep, picked.top)

            let reservedAxisW = showYAxisMarks ? (axisWidth + axisGutter) : 0
            let columnsW = max(1, totalW - reservedAxisW)

            let nCols = slots.count
            let nLayout = max(nCols, 1)
            let rawW = (columnsW - spacing * CGFloat(nLayout - 1)) / CGFloat(nLayout)
            let colW = max(6, floor(rawW))
            let pitch = colW + spacing
            let used = CGFloat(nLayout) * colW + spacing * CGFloat(nLayout - 1)
            let sidePad = max(0, (columnsW - used) / 2.0)

            let autoFilled = slots.firstIndex(where: { $0.range == nil }) ?? nCols
            let filled = min(nCols, filledCount ?? autoFilled)

            ZStack(alignment: .topLeading) {

                // Columns & tracks
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(slots.enumerated()), id: \.1.id) { idx, slot in
                        ZStack(alignment: .bottom) {
                            // Track
                            RoundedRectangle(cornerRadius: colW / 2, style: .continuous)
                                .fill(trackColor)
                                .frame(width: colW, height: trackH)

                            // Range
                            if idx < filled, let r = slot.range {
                                let loV = CGFloat(min(max(0, r.lowerBound), displayTop))
                                let hiV = CGFloat(min(max(0, r.upperBound), displayTop))
                                let yLo = trackH * (1.0 - (loV / CGFloat(displayTop)))
                                let yHi = trackH * (1.0 - (hiV / CGFloat(displayTop)))
                                let rangeHeight = max(1, yLo - yHi)

                                RoundedRectangle(cornerRadius: colW / 2, style: .continuous)
                                    .fill(rangeColor) // <<< solid red
                                    .frame(width: colW, height: rangeHeight)
                                    .offset(y: -(trackH - yLo))
                            }
                        }
                        .frame(width: colW, height: trackH, alignment: .bottom)
                    }
                }
                .padding(.leading, sidePad)
                .frame(width: columnsW, height: trackH, alignment: .bottomLeading)

                // X labels
                GeometryReader { _ in
                    let labelIndices = stride(from: 0, to: nCols, by: labelEvery).map { $0 }
                    ZStack(alignment: .bottomLeading) {
                        ForEach(labelIndices, id: \.self) { idx in
                            if idx < nCols, let text = slots[idx].bottomLabel, !text.isEmpty {
                                let xCenter = sidePad + CGFloat(idx) * pitch + colW / 2
                                Text(text)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(width: 80, height: labelH, alignment: .center)
                                    .position(x: xCenter, y: trackH + labelH / 2)
                            }
                        }
                    }
                }

                // Right axis
                if showYAxisMarks {
                    HeartRightAxis(yMax: displayTop, step: displayStep)
                        .frame(width: axisWidth, height: trackH)
                        .position(x: columnsW + axisWidth / 2 + axisGutter, y: trackH / 2)
                }
            }
            .frame(width: totalW, height: totalH, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .drawingGroup()
    }
}

// MARK: - Adapter view: converts HeartPoint[] into CalmScore-like slots & labels
struct HeartRateCalmChartView: View {
    var points: [HeartPoint]
    var range: HeartRateDetailViewModel.ChartTimeRange
    var domain: ClosedRange<Date>
    
    init(points: [HeartPoint],
         range: HeartRateDetailViewModel.ChartTimeRange,
         domain: ClosedRange<Date>) {
        self.points = points.sorted(by: { $0.time < $1.time })
        self.range = range
        self.domain = domain
    }

    private var yMax: Double {
        let uppers = slots.prefix(filledCount).compactMap { $0.range?.upperBound }
        let maxU = uppers.max() ?? 0
        // Round up to nearest 10. If everything is very low, still give some headroom.
        let rounded = Double(Int(ceil(maxU / 10.0) * 10))
        return max(90, rounded)   // << you can tweak this floor; 90 keeps axis from feeling cramped
    }

    private var filledCount: Int {
        // last index that actually has a range (future/no data are nil)
        if let last = slots.lastIndex(where: { $0.range != nil }) { return last + 1 }
        return 0
    }

    private var slots: [HeartRateRangeSlot] {
        guard !points.isEmpty else { return expectedTimeline.map { HeartRateRangeSlot(range: nil, bottomLabel: $0.label) } }

        let cal = Calendar.current

        // Helper: normalized bucket key (must match VM.bucketStart)
        func key(for date: Date) -> Date {
            switch range {
            case .hourly:
                // 3-minute bucket within the hour of `date`
                let hourStart = cal.dateInterval(of: .hour, for: date)!.start
                let minute = cal.component(.minute, from: date)
                let idx = minute / 3
                return cal.date(byAdding: .minute, value: idx * 3, to: hourStart)!
            case .daily:
                return cal.dateInterval(of: .hour, for: date)!.start
            case .weekly, .monthly:
                return cal.startOfDay(for: date)
            case .yearly:
                // month buckets
                return cal.dateInterval(of: .month, for: date)!.start
            }
        }

        // Build a lookup from bucket-start → min/max
        var table: [TimeInterval: ClosedRange<Double>] = [:]
        table.reserveCapacity(points.count)
        for p in points {
            // normalize the point time to be resilient to any minor drift
            let k = key(for: p.time).timeIntervalSince1970
            let r = p.min...p.max
            if let existing = table[k] {
                table[k] = min(existing.lowerBound, r.lowerBound)...max(existing.upperBound, r.upperBound)
            } else {
                table[k] = r
            }
        }

        // Map expected timeline to ranges
        return expectedTimeline.map { tl in
            let k = key(for: tl.date).timeIntervalSince1970
            let r = table[k]
            return HeartRateRangeSlot(range: r, bottomLabel: tl.label)
        }
    }

    // Build the “CalmScore-style” expected X for each timeframe and provide bottom labels
    private var expectedTimeline: [(date: Date, label: String)] {
        let cal = Calendar.current
        switch range {
        case .hourly:
            // 20 columns: 3-minute buckets within the hour defined by domain.lowerBound
            let startOfHour = cal.dateInterval(of: .hour, for: domain.lowerBound)!.start
            return (0..<20).map { i in
                let d = cal.date(byAdding: .minute, value: i * 3, to: startOfHour)!
                let label: String
                if i == 0 {
                    label = DateFormatter.cached("h").string(from: d)
                } else if i % 5 == 0 { // 15/30/45
                    label = DateFormatter.cached("h:mm a").string(from: d)
                } else {
                    label = ""
                }
                return (d, label)
            }

        case .daily:
            // 24 hourly buckets for the selected day
            let startOfDay = cal.startOfDay(for: domain.lowerBound)
            return (0..<24).map { i in
                let d = cal.date(byAdding: .hour, value: i, to: startOfDay)!
                let lbl = (i % 6 == 0) ? DateFormatter.cached("ha").string(from: d) : ""
                return (d, lbl)
            }

        case .weekly:
            // Sun → Sat of the week containing domain.lowerBound
            let week = cal.dateInterval(of: .weekOfYear, for: domain.lowerBound)!
            let symbols = cal.shortWeekdaySymbols
            return (0..<7).map { i in
                let d = cal.date(byAdding: .day, value: i, to: week.start)!
                let lbl = symbols[(cal.component(.weekday, from: d) - 1) % symbols.count]
                return (cal.startOfDay(for: d), lbl)
            }

        case .monthly:
            // All days in the month of domain.lowerBound; label every 5th
            let monthStart = cal.dateInterval(of: .month, for: domain.lowerBound)!.start
            let days = cal.range(of: .day, in: .month, for: monthStart)!.count
            return (0..<days).map { i in
                let d = cal.date(byAdding: .day, value: i, to: monthStart)!
                let lbl = (i % 5 == 0) ? DateFormatter.cached("d").string(from: d) : ""
                return (cal.startOfDay(for: d), lbl)
            }

        case .yearly:
            // Jan…Dec of the year of domain.lowerBound (first letter)
            let yearStart = cal.dateInterval(of: .year, for: domain.lowerBound)!.start
            let labels = cal.shortMonthSymbols
            return (0..<12).map { i in
                let d = cal.date(byAdding: .month, value: i, to: yearStart)!
                let lbl = labels[i % labels.count].first.map { String($0).uppercased() } ?? ""
                return (cal.dateInterval(of: .month, for: d)!.start, lbl)
            }
        }
    }

    private var spacing: CGFloat {
        switch range {
        case .hourly: return 5
        case .daily:  return 4
        case .weekly: return 14
        case .monthly:return 6
        case .yearly: return 10
        }
    }

    private var labelEvery: Int {
        switch range {
        case .hourly: return 1
        case .daily:  return 1
        case .weekly: return 1
        case .monthly:return 1
        case .yearly: return 1
        }
    }

    var body: some View {
        HeartRateRangeChart(
            slots: slots,
            spacing: spacing,
            labelEvery: labelEvery,
            showYAxisMarks: true,
            axisWidth: 36,
            axisGutter: 8,
            yMax: yMax,
            yStep: 20,
            filledCount: filledCount,
            rangeColor: .red
        )
        .frame(minHeight: 220)
        .background(Color.black)
    }
}

// MARK: - Tiny DF cache (avoid re-allocating formatters)
private extension DateFormatter {
    static func cached(_ fmt: String) -> DateFormatter {
        struct Store { static var cache: [String: DateFormatter] = [:] }
        if let f = Store.cache[fmt] { return f }
        let f = DateFormatter(); f.dateFormat = fmt; Store.cache[fmt] = f; return f
    }
}


// MARK: - Previews
#if DEBUG
import SwiftUI

private enum _HRPreviewFactory {
    static func hourlyPoints() -> [HeartPoint] {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        return (0..<24).map { i in
            let t = cal.date(byAdding: .hour, value: i, to: base)!
            let low = 58.0 + Double((i * 3) % 14)
            let hi  = low + 20.0 + Double((i * 7) % 16)
            return HeartPoint(time: t, min: low, max: hi)
        }
    }

    static func dailyPoints() -> [HeartPoint] {
        // 7 days, 1 bucket per day (min/max across the day)
        let cal = Calendar.current
        let center = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -3, to: center)!
        return (0..<7).map { i in
            let t = cal.date(byAdding: .day, value: i, to: start)!
            let low = 55.0 + Double((i * 5) % 10)
            let hi  = low + 25.0 + Double((i * 9) % 20)
            return HeartPoint(time: t, min: low, max: hi)
        }
    }

    static func weeklyPoints() -> [HeartPoint] {
        // 7 daily buckets for the current week (Sun→Sat)
        let cal = Calendar.current
        let week = cal.dateInterval(of: .weekOfYear, for: Date())!
        return (0..<7).map { i in
            let d = cal.date(byAdding: .day, value: i, to: week.start)!
            let low = 56.0 + Double((i * 4) % 12)
            let hi  = low + 22.0 + Double((i * 6) % 18)
            return HeartPoint(time: cal.startOfDay(for: d), min: low, max: hi)
        }
    }

    static func monthlyPoints() -> [HeartPoint] {
        // daily buckets for the anchor month
        let cal = Calendar.current
        let anchor = Date()
        let start = cal.date(from: cal.dateComponents([.year, .month], from: anchor))!
        let days = cal.range(of: .day, in: .month, for: anchor)!.count
        return (0..<days).map { i in
            let d = cal.date(byAdding: .day, value: i, to: start)!
            let low = 54.0 + Double((i * 2) % 11)
            let hi  = low + 24.0 + Double((i * 3) % 17)
            return HeartPoint(time: cal.startOfDay(for: d), min: low, max: hi)
        }
    }

    static func yearlyPoints() -> [HeartPoint] {
        // monthly buckets for the year (12)
        let cal = Calendar.current
        let yearStart = cal.date(from: cal.dateComponents([.year], from: Date()))!
        return (0..<12).map { i in
            let m = cal.date(byAdding: .month, value: i, to: yearStart)!
            let low = 53.0 + Double((i * 3) % 10)
            let hi  = low + 23.0 + Double((i * 5) % 19)
            return HeartPoint(time: cal.dateInterval(of: .month, for: m)!.start, min: low, max: hi)
        }
    }
}

struct HeartRateCalmChartView_Previews: PreviewProvider {
    
    let s = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -3, to: Date())!)
    let e = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: +4, to: Date())!)
    
    
    static var previews: some View {
        Group {
            HeartRateCalmChartView(
                points: _HRPreviewFactory.hourlyPoints(),
                range: .hourly,
                domain: {
                    let cal = Calendar.current
                    let now = Date()
                    let h = cal.dateInterval(of: .hour, for: now)!.start
                    return h...cal.date(byAdding: .hour, value: 1, to: h)!
                }()
            )
            .frame(height: 260)
            .padding()
            .background(Color.black)
            .previewDisplayName("Hourly (24)")

            HeartRateCalmChartView(
                points: _HRPreviewFactory.dailyPoints(),
                range: .daily,
                domain: {
                    let cal = Calendar.current
                    let c = cal.startOfDay(for: Date())
                    let s = cal.date(byAdding: .day, value: -3, to: c)!
                    let e = cal.date(byAdding: .day, value: +4, to: c)!
                    return s...e
                }()
            )
            .frame(height: 260)
            .padding()
            .background(Color.black)
            .previewDisplayName("Daily (7 days)")

            HeartRateCalmChartView(
                points: _HRPreviewFactory.weeklyPoints(),
                range: .weekly,
                domain: {
                    let cal = Calendar.current
                    let week = cal.dateInterval(of: .weekOfYear, for: Date())!
                    return week.start...cal.date(byAdding: .day, value: 7, to: week.start)!
                }()
            )
            .frame(height: 260)
            .padding()
            .background(Color.black)
            .previewDisplayName("Weekly (Sun–Sat)")

            HeartRateCalmChartView(
                points: _HRPreviewFactory.monthlyPoints(),
                range: .monthly,
                domain: {
                    let cal = Calendar.current
                    let m = cal.dateInterval(of: .month, for: Date())!
                    return m.start...cal.date(byAdding: .month, value: 1, to: m.start)!
                }()
            )
            .frame(height: 260)
            .padding()
            .background(Color.black)
            .previewDisplayName("Monthly (days)")

            HeartRateCalmChartView(
                points: _HRPreviewFactory.yearlyPoints(),
                range: .yearly,
                domain: {
                    let cal = Calendar.current
                    let y = cal.dateInterval(of: .year, for: Date())!
                    return y.start...cal.date(byAdding: .year, value: 1, to: y.start)!
                }()
            )
            .frame(height: 260)
            .padding()
            .background(Color.black)
            .previewDisplayName("Yearly (12 months)")
        }
        .preferredColorScheme(.dark)
    }
}
#endif
