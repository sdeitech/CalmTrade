//
//  HRVRangeCalmChartView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 01/10/25.
//

import SwiftUI
import Foundation

// MARK: - “nice” top for HRV (200 ticks)
@inline(__always)
private func hrvChooseTop(rangeMax: Double) -> Double {
    let step = 200.0
    let safeMax = max(0.0, rangeMax)
    let top = ceil(safeMax / step) * step
    return max(step, top) // at least 200
}

struct HRVRangeSlot: Identifiable {
    let id = UUID()
    var range: ClosedRange<Double>?
    var bottomLabel: String?
}

private struct HRVRightAxis: View {
    let top: Double
    var body: some View {
        GeometryReader { geo in
            let h = max(1, geo.size.height)
            let ticks: [Double] = stride(from: 0.0, through: top, by: 200.0).map { $0 }
            ZStack(alignment: .topLeading) {
                ForEach(ticks, id: \.self) { t in
                    let frac = CGFloat(t / max(1, top))
                    let y = h * (1 - frac)
                    Path { p in
                        p.move(to: .init(x: 0, y: y))
                        p.addLine(to: .init(x: geo.size.width, y: y))
                    }
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)

                    Text("\(Int(t))")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .position(x: geo.size.width - 10, y: y)
                }
            }
        }
    }
}

struct HRVRangeChart: View {
    var slots: [HRVRangeSlot]
    var filledCount: Int

    // Styling (HRV magenta like your line chart)
    var barColor: Color = Color(red: 1.0, green: 0.31, blue: 0.49)
    var trackColor: Color = .white.opacity(0.08)

    // Layout
    var spacing: CGFloat = 6
    var labelEvery: Int = 1
    var axisWidth: CGFloat = 36
    var axisGutter: CGFloat = 8

    // Y
    var yTop: Double

    var body: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let totalH = max(1, geo.size.height)
            let labelH: CGFloat = 18
            let trackH = max(1, totalH - labelH)

            let reservedAxisW = axisWidth + axisGutter
            let columnsW = max(1, totalW - reservedAxisW)

            let n = max(slots.count, 1)
            let rawW = (columnsW - spacing * CGFloat(n - 1)) / CGFloat(n)
            let colW = max(6, floor(rawW))
            let pitch = colW + spacing
            let used = CGFloat(n) * colW + spacing * CGFloat(n - 1)
            let sidePad = max(0, (columnsW - used) / 2.0)

            ZStack(alignment: .topLeading) {

                // Columns
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(slots.enumerated()), id: \.1.id) { idx, slot in
                        ZStack(alignment: .bottom) {
                            // track
                            RoundedRectangle(cornerRadius: colW / 2, style: .continuous)
                                .fill(trackColor)
                                .frame(width: colW, height: trackH)

                            // range bar
                            if idx < filledCount, let r = slot.range {
                                let lo = min(max(0, r.lowerBound), yTop)
                                let hi = min(max(0, r.upperBound), yTop)
                                let yLo = trackH * (1.0 - CGFloat(lo / yTop))
                                let yHi = trackH * (1.0 - CGFloat(hi / yTop))
                                let h = max(1, yLo - yHi)

                                RoundedRectangle(cornerRadius: colW / 2, style: .continuous)
                                    .fill(barColor)
                                    .frame(width: colW, height: h)
                                    .offset(y: -(trackH - yLo))
                            }
                        }
                        .frame(width: colW, height: trackH, alignment: .bottom)
                    }
                }
                .padding(.leading, sidePad)
                .frame(width: columnsW, height: trackH, alignment: .bottomLeading)

                // bottom labels
                GeometryReader { _ in
                    let idxs = stride(from: 0, to: slots.count, by: max(1, labelEvery))
                    ZStack(alignment: .bottomLeading) {
                        ForEach(Array(idxs), id: \.self) { idx in
                            if idx < slots.count, let text = slots[idx].bottomLabel, !text.isEmpty {
                                let xCenter = sidePad + CGFloat(idx) * pitch + colW / 2
                                Text(text)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(width: 80, height: labelH)
                                    .position(x: xCenter, y: trackH + labelH / 2)
                            }
                        }
                    }
                }

                // right axis
                HRVRightAxis(top: yTop)
                    .frame(width: axisWidth, height: trackH)
                    .position(x: columnsW + axisWidth / 2 + axisGutter, y: trackH / 2)
            }
        }
        .frame(minHeight: 220)
        .background(Color.black)
        .drawingGroup()
    }
}

// Adapter, identical layout logic to HeartRateCalmChartView
struct HRVRangeCalmChartView: View {
    enum TimeRange { case hourly, daily, weekly, monthly, yearly }

    struct HRVRangePoint: Identifiable, Hashable {
        var id: Double { time.timeIntervalSince1970 }
        let time: Date
        let min: Double
        let max: Double
    }

    var points: [HRVRangePoint]
    var range: TimeRange
    var domain: ClosedRange<Date>

    private var slots: [HRVRangeSlot] {
        let pts = points.sorted { $0.time < $1.time }
        guard !pts.isEmpty else { return expectedTimeline.map { HRVRangeSlot(range: nil, bottomLabel: $0.label) } }

        var table: [TimeInterval: ClosedRange<Double>] = [:]
        for p in pts { table[p.time.timeIntervalSince1970] = p.min...p.max }

        return expectedTimeline.map { t in
            let key = t.date.timeIntervalSince1970
            return HRVRangeSlot(range: table[key], bottomLabel: t.label)
        }
    }

    private var filledCount: Int {
        if let last = slots.lastIndex(where: { $0.range != nil }) { return last + 1 }
        return 0
    }

    private var yTop: Double {
        let uppers = slots.prefix(filledCount).compactMap { $0.range?.upperBound }
        return hrvChooseTop(rangeMax: uppers.max() ?? 0)
    }

    // same X layout as HeartRateCalmChartView
    private var expectedTimeline: [(date: Date, label: String)] {
        let cal = Calendar.current
        switch range {
        case .hourly:
            let start = cal.dateInterval(of: .hour, for: domain.lowerBound)!.start
            return (0..<20).map { i in
                let d = cal.date(byAdding: .minute, value: i * 3, to: start)!
                let lbl: String
                if i == 0 {
                    lbl = DateFormatter.cached("h").string(from: d)            // e.g. "9"
                } else if i % 5 == 0 {
                    lbl = DateFormatter.cached("h:mm a").string(from: d)       // e.g. "9:15 AM"
                } else {
                    lbl = ""
                }
                return (d, lbl)
            }
        case .daily:
            let base = cal.startOfDay(for: domain.lowerBound)
            return (0..<24).map { i in
                let d = cal.date(byAdding: .hour, value: i, to: base)!
                let lbl = (i % 6 == 0) ? DateFormatter.cached("ha").string(from: d) : ""
                return (d, lbl)
            }
        case .weekly:
            let week = cal.dateInterval(of: .weekOfYear, for: domain.lowerBound)!
            let syms = cal.shortWeekdaySymbols
            return (0..<7).map { i in
                let d = cal.date(byAdding: .day, value: i, to: week.start)!
                let lbl = syms[(cal.component(.weekday, from: d) - 1) % syms.count]
                return (cal.startOfDay(for: d), lbl)
            }
        case .monthly:
            let anchor = domain.lowerBound
            let start = cal.date(from: cal.dateComponents([.year, .month], from: anchor))!
            let days = cal.range(of: .day, in: .month, for: anchor)!.count
            return (0..<days).map { i in
                let d = cal.date(byAdding: .day, value: i, to: start)!
                let lbl = (i % 5 == 0) ? DateFormatter.cached("d").string(from: d) : ""
                return (cal.startOfDay(for: d), lbl)
            }
        case .yearly:
            let yearStart = cal.date(from: cal.dateComponents([.year], from: domain.lowerBound))!
            let labels = cal.shortMonthSymbols
            return (0..<12).map { i in
                let d = cal.date(byAdding: .month, value: i, to: yearStart)!
                let lbl = labels[i % labels.count].prefix(1).uppercased()
                return (cal.dateInterval(of: .month, for: d)!.start, lbl)
            }
        }
    }

    var body: some View {
        HRVRangeChart(
            slots: slots,
            filledCount: filledCount,
            barColor: Color(cgColor: UIColor.init("AF52DE").cgColor),//Color(red: 1.0, green: 0.31, blue: 0.49),
            trackColor: .white.opacity(0.08),
            spacing: { switch range { case .hourly: return 5; case .daily: return 4; case .weekly: return 14; case .monthly: return 6; case .yearly: return 10 } }(),
            labelEvery: 1,
            axisWidth: 36,
            axisGutter: 8,
            yTop: yTop
        )
        .frame(minHeight: 220)
        .background(Color.black)
    }
}

private extension DateFormatter {
    static func cached(_ fmt: String) -> DateFormatter {
        struct Store { static var cache: [String: DateFormatter] = [:] }
        if let f = Store.cache[fmt] { return f }
        let f = DateFormatter(); f.dateFormat = fmt; Store.cache[fmt] = f; return f
    }
}

#if DEBUG
import SwiftUI

private enum _HRVPreviewFactory {
    static func hourlyPoints() -> [HRVRangeCalmChartView.HRVRangePoint] {
        // 20 buckets (3-min) within current hour
        let cal = Calendar.current
        let hourStart = cal.dateInterval(of: .hour, for: Date())!.start
        return (0..<20).map { i in
            let t = cal.date(byAdding: .minute, value: i * 3, to: hourStart)!
            // fake min/max in a reasonable HRV range
            let minv = 30.0 + Double((i * 7) % 25)       // 30…54
            let maxv = minv + 40.0 + Double((i * 5) % 45) // +40…+84
            return .init(time: t, min: minv, max: maxv)
        }
    }

    static func dailyPoints() -> [HRVRangeCalmChartView.HRVRangePoint] {
        // 24 hourly buckets for today
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return (0..<24).map { i in
            let t = cal.date(byAdding: .hour, value: i, to: start)!
            let minv = 25.0 + Double((i * 3) % 35)
            let maxv = minv + 60.0 + Double((i * 4) % 60)
            return .init(time: t, min: minv, max: maxv)
        }
    }

    static func weeklyPoints() -> [HRVRangeCalmChartView.HRVRangePoint] {
        // 7 daily buckets, Sun→Sat of current week
        let cal = Calendar.current
        let week = cal.dateInterval(of: .weekOfYear, for: Date())!
        return (0..<7).map { i in
            let d = cal.date(byAdding: .day, value: i, to: week.start)!
            let t = cal.startOfDay(for: d)
            let minv = 28.0 + Double((i * 6) % 32)
            let maxv = minv + 70.0 + Double((i * 2) % 50)
            return .init(time: t, min: minv, max: maxv)
        }
    }

    static func monthlyPoints() -> [HRVRangeCalmChartView.HRVRangePoint] {
        // daily buckets for anchor month
        let cal = Calendar.current
        let anchor = Date()
        let start = cal.date(from: cal.dateComponents([.year, .month], from: anchor))!
        let days = cal.range(of: .day, in: .month, for: anchor)!.count
        return (0..<days).map { i in
            let d = cal.date(byAdding: .day, value: i, to: start)!
            let t = cal.startOfDay(for: d)
            let minv = 26.0 + Double((i * 4) % 28)
            let maxv = minv + 65.0 + Double((i * 3) % 55)
            return .init(time: t, min: minv, max: maxv)
        }
    }

    static func yearlyPoints() -> [HRVRangeCalmChartView.HRVRangePoint] {
        // 12 monthly buckets for current year
        let cal = Calendar.current
        let yearStart = cal.date(from: cal.dateComponents([.year], from: Date()))!
        return (0..<12).map { i in
            let m = cal.date(byAdding: .month, value: i, to: yearStart)!
            let t = cal.dateInterval(of: .month, for: m)!.start
            let minv = 24.0 + Double((i * 5) % 30)
            let maxv = minv + 75.0 + Double((i * 7) % 50)
            return .init(time: t, min: minv, max: maxv)
        }
    }
}

struct HRVRangeCalmChartView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HRVRangeCalmChartView(
                points: _HRVPreviewFactory.hourlyPoints(),
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
            .previewDisplayName("Hourly (3-min buckets)")

            HRVRangeCalmChartView(
                points: _HRVPreviewFactory.dailyPoints(),
                range: .daily,
                domain: {
                    let cal = Calendar.current
                    let start = cal.startOfDay(for: Date())
                    return start...cal.date(byAdding: .day, value: 1, to: start)!
                }()
            )
            .frame(height: 260)
            .padding()
            .background(Color.black)
            .previewDisplayName("Daily (hourly buckets)")

            HRVRangeCalmChartView(
                points: _HRVPreviewFactory.weeklyPoints(),
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
            .previewDisplayName("Weekly (daily buckets)")

            HRVRangeCalmChartView(
                points: _HRVPreviewFactory.monthlyPoints(),
                range: .monthly,
                domain: {
                    let cal = Calendar.current
                    let month = cal.dateInterval(of: .month, for: Date())!
                    return month.start...cal.date(byAdding: .month, value: 1, to: month.start)!
                }()
            )
            .frame(height: 260)
            .padding()
            .background(Color.black)
            .previewDisplayName("Monthly (daily buckets)")

            HRVRangeCalmChartView(
                points: _HRVPreviewFactory.yearlyPoints(),
                range: .yearly,
                domain: {
                    let cal = Calendar.current
                    let year = cal.dateInterval(of: .year, for: Date())!
                    return year.start...cal.date(byAdding: .year, value: 1, to: year.start)!
                }()
            )
            .frame(height: 260)
            .padding()
            .background(Color.black)
            .previewDisplayName("Yearly (monthly buckets)")
        }
        .preferredColorScheme(.dark)
    }
}
#endif
