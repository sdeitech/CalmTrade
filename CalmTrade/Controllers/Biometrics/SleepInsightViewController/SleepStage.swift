//
//  SleepStage.swift
//  CalmTrade
//
//  Created by Anas Parekh on 08/09/25.
//

import SwiftUI

// MARK: - Normalized Sleep Stage (internal storage uses Int)
public enum SleepStage: Int, CaseIterable, Identifiable, Codable {

    case awake = 0
    case rem   = 1
    case core  = 2
    case deep  = 3

    public var id: Int { rawValue }

    public static var displayOrder: [SleepStage] { [.awake, .rem, .core, .deep] }

    // MARK: - Display Names
    public var displayName: String {
        switch self {
        case .awake: return "Awake"
        case .rem:   return "REM"
        case .core:  return "Core"
        case .deep:  return "Deep"
        }
    }

    // MARK: - Colors (Apple-style dark palette)
    public var color: Color {
        switch self {
        case .awake: return Color(red: 0.99, green: 0.45, blue: 0.45)
        case .rem:   return Color(red: 0.50, green: 0.82, blue: 1.00)
        case .core:  return Color(red: 0.24, green: 0.60, blue: 1.00)
        case .deep:  return Color(red: 0.37, green: 0.32, blue: 0.95)
        }
    }

    public var gradient: Gradient {
        let c = color
        return Gradient(colors: [c.opacity(0.95), c.opacity(0.78)])
    }

    public var strokeColor: Color {
        Color.white.opacity(0.28)
    }

    /// Used by repository to store stage as Int16
    public var rawInt: Int { rawValue }

    /// Safe initializer from integer (used when decoding CoreData)
    public static func fromRaw(_ raw: Int) -> SleepStage {
        return SleepStage(rawValue: raw) ?? .core
    }
}


// MARK: - Sleep Segment
public struct SleepSegment: Identifiable, Hashable {
    public var id: UUID
    public var stage: SleepStage
    public var start: Date
    public var end: Date
    public var source: SleepDataSource

    public init(
        id: UUID = UUID(),
        stage: SleepStage,
        start: Date,
        end: Date,
        source: SleepDataSource = .appleHealth
    ) {
        self.id = id
        self.stage = stage
        self.start = start
        self.end = end
        self.source = source
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }
}


// MARK: - Axis scale (chart time windows)
public enum AxisScale {
    case daily
    case weekly
    case monthly
}

// MARK: - Chart View (Apple Health–style Daily rendering)
public struct SleepCycleChart: View {
    public var start: Date
    public var end: Date
    public var segments: [SleepSegment]
    public var axisScale: AxisScale = .daily

    // Styling
    public var backgroundColor: Color = .black
    public var gridColor: Color = Color.white.opacity(0.12)
    public var axisTextColor: Color = Color.white.opacity(0.65)
    public var axisFont: Font = .system(size: 12, weight: .semibold, design: .rounded)
    public var cornerRadius: CGFloat = 0
    public var chartInsets = EdgeInsets(top: 0, leading: 58, bottom: 32, trailing: 8)

    public init(
        start: Date,
        end: Date,
        segments: [SleepSegment],
        axisScale: AxisScale = .daily,
        backgroundColor: Color = .black,
        gridColor: Color = Color.white.opacity(0.12),
        axisTextColor: Color = Color.white.opacity(0.65),
        axisFont: Font = .system(size: 12, weight: .semibold, design: .rounded),
        cornerRadius: CGFloat = 0
    ) {
        self.start = start
        self.end = end
        self.segments = segments
        self.axisScale = axisScale
        self.backgroundColor = backgroundColor
        self.gridColor = gridColor
        self.axisTextColor = axisTextColor
        self.axisFont = axisFont
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        GeometryReader { geo in
            let win = displayWindow(fallbackStart: start, fallbackEnd: end, segments: segments, scale: axisScale)
            let displayStart = win.start
            let displayEnd   = win.end

            let bands = SleepStage.displayOrder.count
            let bandHeight = (geo.size.height - chartInsets.top - chartInsets.bottom) / CGFloat(bands)

            ZStack {
                backgroundColor

                // Grid (Apple density & opacity)
                Canvas { ctx, size in
                    let rect = chartRect(size: size)

                    // Horizontal bands
                    for i in 0...bands {
                        let y = rect.minY + (CGFloat(i) * rect.height / CGFloat(bands))
                        var p = Path()
                        p.move(to: CGPoint(x: rect.minX, y: y))
                        p.addLine(to: CGPoint(x: rect.maxX, y: y))
                        ctx.stroke(p, with: .color(gridColor), lineWidth: 1)
                    }

                    // Vertical ticks — Apple: AM only for Daily window
                    let ticks = tickDates(scale: axisScale, start: displayStart, end: displayEnd, maxWidth: rect.width)
                    for t in ticks {
                        let x = xPosition(for: t, start: displayStart, end: displayEnd, in: rect)
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: rect.minY))
                        p.addLine(to: CGPoint(x: x, y: rect.maxY))
                        let isMidnight = Calendar.current.component(.hour, from: t) == 0
                        ctx.stroke(p, with: .color(gridColor.opacity(isMidnight ? 0.22 : 0.12)),
                                   lineWidth: isMidnight ? 1.25 : 1)
                    }
                }

                // Segments (pills, Apple gradient + stroke) and transition rails
                Canvas { ctx, size in
                    let rect = chartRect(size: size)
                    let bandPad: CGFloat = 6
                    let pillRadius: CGFloat = 10

                    // Clamp and sort
                    let clamped = clampSegments(segments, within: displayStart...displayEnd)
                        .sorted { $0.start < $1.start }

                    // Draw pills
                    for seg in clamped {
                        guard seg.end > seg.start else { continue }
                        let x1 = xPosition(for: seg.start, start: displayStart, end: displayEnd, in: rect)
                        let x2 = xPosition(for: seg.end,   start: displayStart, end: displayEnd, in: rect)
                        let bandIndex = SleepStage.displayOrder.firstIndex(of: seg.stage) ?? 0
                        let yBandTop = rect.minY + CGFloat(bandIndex) * (rect.height / CGFloat(bands))
                        let h = (rect.height / CGFloat(bands)) - bandPad * 2

                        let r = CGRect(
                            x: max(rect.minX, min(x1, x2)),
                            y: yBandTop + bandPad,
                            width: max(3, abs(x2 - x1)),
                            height: h
                        )

                        let path = RoundedRectangle(cornerRadius: pillRadius, style: .continuous).path(in: r)

                        // Fill (gradient)
                        ctx.fill(path,
                                 with: .linearGradient(seg.stage.gradient,
                                                       startPoint: CGPoint(x: r.minX, y: r.minY),
                                                       endPoint:   CGPoint(x: r.minX, y: r.maxY)))
                        // Subtle outline
                        ctx.stroke(path, with: .color(seg.stage.strokeColor), lineWidth: 0.8)
                    }

                    // Transition rails
                    drawTransitionRails(ctx: &ctx,
                                        rect: rect,
                                        segments: clamped,
                                        start: displayStart,
                                        end: displayEnd,
                                        bands: bands)
                }

                // Y labels
                VStack(spacing: 0) {
                    ForEach(SleepStage.displayOrder, id: \.self) { stage in
                        HStack(spacing: 8) {
                            Text(verbatim: stage.displayName)
                                .font(axisFont)
                                .foregroundColor(axisTextColor)
                                .frame(width: 52, alignment: .leading)
                            Spacer(minLength: 0)
                        }
                        // ✅ Clamp bandHeight to a sane positive minimum (prevents crash)
                        .frame(height: max(1, bandHeight.isFinite ? bandHeight : 0))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 6)

                // X labels
                HStack(spacing: 0) {
                    let dates = tickDates(scale: axisScale, start: displayStart, end: displayEnd,
                                          maxWidth: geo.size.width - chartInsets.leading - chartInsets.trailing)
                    ForEach(dates, id: \.self) { t in
                        Text(tickLabel(for: t, scale: axisScale))
                            .font(axisFont)
                            .foregroundColor(axisTextColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .frame(height: 24)
                .padding(.leading, chartInsets.leading)
                .padding(.trailing, chartInsets.trailing)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .compositingGroup()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sleep Cycle Chart")
    }
    
    /// Data-driven window for Daily: use [firstSegment.start, lastSegment.end] with padding,
    /// aligned to whole hours. Falls back to 6PM→12PM if no segments.
    /// Weekly/Monthly: passthrough.
    private func displayWindow(fallbackStart: Date,
                               fallbackEnd: Date,
                               segments: [SleepSegment],
                               scale: AxisScale) -> (start: Date, end: Date) {
        guard scale == .daily, let first = segments.min(by: { $0.start < $1.start }),
              let last = segments.max(by: { $0.end < $1.end }) else {
            // no segments or not daily -> keep your existing behavior
            return alignedWindow(start: fallbackStart, end: fallbackEnd, scale: scale)
        }

        let cal = Calendar.current
        let rawStart = first.start
        let rawEnd   = last.end

        // pad ~30 min each side (like Apple does when there’s buffer),
        // but don’t exceed ±90 min and don’t cross “now” on the right.
        let minPad: TimeInterval = 30 * 60
        let maxPad: TimeInterval = 90 * 60
        let span = max(0, rawEnd.timeIntervalSince(rawStart))
        let pad  = min(maxPad, max(minPad, span * 0.1))

        var s = rawStart.addingTimeInterval(-pad)
        var e = rawEnd.addingTimeInterval(+pad)

        // Align to whole hours (floor start, ceil end)
        s = cal.date(bySetting: .minute, value: 0, of: s) ?? s
        s = cal.date(bySetting: .second, value: 0, of: s) ?? s
        if s > rawStart { s = cal.date(byAdding: .hour, value: -1, to: s) ?? s }

        if let snappedE = cal.date(bySettingHour: cal.component(.hour, from: e), minute: 0, second: 0, of: e) {
            e = snappedE
            if e < rawEnd { e = cal.date(byAdding: .hour, value: 1, to: e) ?? e }
        }

        // Ensure a reasonable minimum and maximum span (Apple never shows <3h or >16h in one night grid)
        let minSpan: TimeInterval = 3 * 3600
        let maxSpan: TimeInterval = 16 * 3600
        if e.timeIntervalSince(s) < minSpan { e = s.addingTimeInterval(minSpan) }
        if e.timeIntervalSince(s) > maxSpan { e = s.addingTimeInterval(maxSpan) }

        return (s, e)
    }


    // MARK: - Rails (single or double)
    private func drawTransitionRails(ctx: inout GraphicsContext,
                                     rect: CGRect,
                                     segments: [SleepSegment],
                                     start: Date,
                                     end: Date,
                                     bands: Int)
    {
        let eps: TimeInterval = 60  // 1 min boundary tolerance
        let bandH = rect.height / CGFloat(bands)

        guard segments.count >= 2 else { return }

        // We scan boundaries and group by timestamp (within eps), so we can draw double rails if needed.
        var boundaries: [(time: Date, pairs: [(SleepSegment, SleepSegment)])] = []
        var i = 0
        while i < segments.count - 1 {
            var group: [(SleepSegment, SleepSegment)] = []
            let t0 = segments[i+1].start
            group.append((segments[i], segments[i+1]))

            var j = i + 1
            while j < segments.count - 1 {
                let nextStart = segments[j+1].start
                if abs(nextStart.timeIntervalSince(t0)) <= eps {
                    group.append((segments[j], segments[j+1]))
                    j += 1
                } else {
                    break
                }
            }
            boundaries.append((time: t0, pairs: group))
            i = j
        }

        for b in boundaries {
            let x = xPosition(for: b.time, start: start, end: end, in: rect)

            // When we have multiple pairs at the same time, draw a double rail with slight horizontal offset.
            let count = b.pairs.count
            let offsets: [CGFloat]
            if count >= 2 {
                offsets = [-0.9, 0.9]  // two rails ~1.8pt apart (Apple look)
            } else {
                offsets = [0.0]
            }

            for (k, pair) in b.pairs.enumerated() {
                let (a, c) = pair
                guard a.stage != c.stage else { continue }

                let idxA = SleepStage.displayOrder.firstIndex(of: a.stage) ?? 0
                let idxC = SleepStage.displayOrder.firstIndex(of: c.stage) ?? 0
                let yA = rect.minY + CGFloat(idxA) * bandH + bandH/2
                let yC = rect.minY + CGFloat(idxC) * bandH + bandH/2

                var p = Path()
                p.move(to: CGPoint(x: x + offsets[min(k, offsets.count-1)], y: min(yA, yC)))
                p.addLine(to: CGPoint(x: x + offsets[min(k, offsets.count-1)], y: max(yA, yC)))
                ctx.stroke(p, with: .color(Color.white.opacity(0.28)), lineWidth: 1.2)
            }
        }
    }

    // MARK: - Helpers
    private func chartRect(size: CGSize) -> CGRect {
        CGRect(
            x: chartInsets.leading,
            y: chartInsets.top,
            width: size.width - chartInsets.leading - chartInsets.trailing,
            height: size.height - chartInsets.top - chartInsets.bottom
        )
    }

    // Exact Apple night window for Daily
    private func alignedWindow(start: Date, end: Date, scale: AxisScale) -> (start: Date, end: Date) {
        guard scale == .daily else { return (start, end) }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: end)
        let endNoon  = cal.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart)!  // 12:00 PM
        let start6pm = cal.date(byAdding: .hour, value: -18, to: endNoon)!               // previous 6:00 PM
        return (start6pm, endNoon)
    }

    private func clampSegments(_ segs: [SleepSegment], within window: ClosedRange<Date>) -> [SleepSegment] {
        segs.compactMap { s in
            let st = max(s.start, window.lowerBound)
            let en = min(s.end,   window.upperBound)
            return (en > st) ? SleepSegment(stage: s.stage, start: st, end: en) : nil
        }
    }

    private func xPosition(for time: Date, start: Date, end: Date, in rect: CGRect) -> CGFloat {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return rect.minX }
        let clamped = min(max(time.timeIntervalSince(start), 0), total)
        return rect.minX + CGFloat(clamped / total) * rect.width
    }

    // MARK: Ticks & Labels
    private func tickDates(scale: AxisScale,
                           start: Date,
                           end: Date,
                           maxWidth: CGFloat = .greatestFiniteMagnitude) -> [Date] {
        let cal = Calendar.current

        switch scale {
        case .daily:
            // Target ~4–5 labels, adapt to width and span.
            let approxPerLabel: CGFloat = 70
            let maxLabels = max(2, Int(maxWidth / approxPerLabel))

            let hours = max(1, Int(ceil(end.timeIntervalSince(start) / 3600)))
            // choose a nice step (1/2/3/4) to stay near the target label count
            let target = min(maxLabels, 6)
            let rawStep = max(1, Int(round(Double(hours) / Double(target))))
            // snap to a friendly hour step
            let step = [1,2,3,4].min(by: { abs($0 - rawStep) < abs($1 - rawStep) }) ?? rawStep

            // first tick = next whole hour ≥ start
            var first = cal.date(bySetting: .minute, value: 0, of: start) ?? start
            first = cal.date(bySetting: .second, value: 0, of: first) ?? first
            if first < start { first = cal.date(byAdding: .hour, value: 1, to: first) ?? first }

            var ticks: [Date] = []
            var t = first
            while t <= end {
                ticks.append(t)
                t = cal.date(byAdding: .hour, value: step, to: t) ?? end.addingTimeInterval(1)
            }
            // Always include the ending hour marker if aligned and not duplicate
            if cal.component(.minute, from: end) == 0 && cal.component(.second, from: end) == 0 {
                if ticks.last != end { ticks.append(end) }
            }
            return ticks

        case .weekly:
            var d = cal.startOfDay(for: start); var out: [Date] = [d]
            while let next = cal.date(byAdding: .day, value: 1, to: d), next <= end { out.append(next); d = next }
            return out

        case .monthly:
            guard let startWeek = cal.dateInterval(of: .weekOfYear, for: start)?.start else { return [] }
            var ticks: [Date] = [startWeek]
            while let next = cal.date(byAdding: .weekOfYear, value: 1, to: ticks.last!), next <= end { ticks.append(next) }
            if let endWeek = cal.dateInterval(of: .weekOfYear, for: end)?.start, endWeek == end, !ticks.contains(endWeek) {
                ticks.append(endWeek)
            }
            return ticks
        }
    }

    private func tickLabel(for date: Date, scale: AxisScale) -> String {
        let f = DateFormatter()
        switch scale {
        case .daily:   f.dateFormat = "ha"
        case .weekly:  f.dateFormat = "EEE"
        case .monthly: return "WK \(Calendar.current.component(.weekOfYear, from: date))"
        }
        return f.string(from: date).uppercased()
    }
}


// MARK: - Preview (optional)
struct SleepCycleChart_Previews: PreviewProvider {
    static var previews: some View {
        let base = Calendar.current.date(from: DateComponents(year: 2025, month: 8, day: 5, hour: 22))! // 10PM
        let end  = Calendar.current.date(byAdding: .hour, value: 20, to: base)! // to ~6PM next day
        var segs: [SleepSegment] = [
            .init(stage: .core, start: base.addingTimeInterval(60*60*1.0), end: base.addingTimeInterval(60*60*1.5)),
            .init(stage: .deep, start: base.addingTimeInterval(60*60*1.5), end: base.addingTimeInterval(60*60*2.3)),
            .init(stage: .rem,  start: base.addingTimeInterval(60*60*3.0), end: base.addingTimeInterval(60*60*3.6)),
            .init(stage: .core, start: base.addingTimeInterval(60*60*3.6), end: base.addingTimeInterval(60*60*6.0)),
            .init(stage: .rem,  start: base.addingTimeInterval(60*60*12.0), end: base.addingTimeInterval(60*60*13.0)),
            .init(stage: .core, start: base.addingTimeInterval(60*60*13.0), end: base.addingTimeInterval(60*60*15.0))
        ]
        segs.append(.init(stage: .awake,
                          start: base.addingTimeInterval(60*60*4.99),
                          end:   base.addingTimeInterval(60*60*5.03)))

        return Group {
            SleepCycleChart(start: base, end: end, segments: segs, axisScale: .daily)
                .frame(width: 360, height: 220)
                .background(Color.black)
                .padding()
                .previewDisplayName("Daily (hours)")

            let wStart = Calendar.current.startOfDay(for: Date())
            let wEnd   = Calendar.current.date(byAdding: .day, value: 7, to: wStart)!
            SleepCycleChart(start: wStart, end: wEnd, segments: [], axisScale: .weekly)
                .frame(width: 360, height: 220)
                .background(Color.black)
                .padding()
                .previewDisplayName("Weekly (days)")

            let mStart = Calendar.current.date(from: DateComponents(year: 2025, month: 8, day: 1))!
            let mEnd   = Calendar.current.date(from: DateComponents(year: 2025, month: 9, day: 1))!
            SleepCycleChart(start: mStart, end: mEnd, segments: [], axisScale: .monthly)
                .frame(width: 360, height: 220)
                .background(Color.black)
                .padding()
                .previewDisplayName("Monthly (weeks)")
        }
    }
}
