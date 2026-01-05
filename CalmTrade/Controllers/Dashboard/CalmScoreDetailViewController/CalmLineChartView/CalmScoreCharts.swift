//
//  CalmScoreCharts.swift
//  CalmTrade
//
//  Created by Anas Parekh on 23/09/25.
//

import SwiftUI

// Choose a "nice" step from {1,2,5}×10^k and a rounded top multiple of that step.
@inline(__always)
private func chooseStepAndTop(rangeMax: Double, maxTicks: Int) -> (step: Double, top: Double) {
    let safeMax = max(0.0, rangeMax)
    let ticks = max(2, maxTicks) // at least 2 ticks (0 and top)

    // desired (raw) step
    let raw = (ticks > 0) ? (safeMax / Double(ticks)) : safeMax

    // snap to 1/2/5 × 10^k
    guard raw > 0 else { return (step: 5, top: 20) } // harmless default
    let exp = floor(log10(raw))
    let base = pow(10.0, exp)
    let frac = raw / base

    let niceFrac: Double
    if frac <= 1 { niceFrac = 1 }
    else if frac <= 2 { niceFrac = 2 }
    else if frac <= 5 { niceFrac = 5 }
    else { niceFrac = 10 }

    let step = niceFrac * base
    // round up the top to a multiple of step; cap at 100 to match domain
    let top  = min(100, ceil(safeMax / step) * step)
    return (step, max(step, top))
}

// MARK: - Color & Gradient (0…100 → red→orange→yellow→green)
public enum CalmScoreColors {
    static let red    = Color(red: 0.95, green: 0.30, blue: 0.25)
    static let orange = Color(red: 0.98, green: 0.60, blue: 0.20)
    static let yellow = Color(red: 0.98, green: 0.85, blue: 0.25)
    static let green  = Color(red: 0.45, green: 0.85, blue: 0.40)

    static var verticalScaleGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: red,    location: 0.00),
                .init(color: orange, location: 0.39),
                .init(color: yellow, location: 0.69),
                .init(color: green,  location: 1.00)
            ]),
            startPoint: .bottom, endPoint: .top
        )
    }

    // ---- NEW: map a 0…100 value to a color on the same scale as the gauge ----
    static func color(for value: Double) -> Color {
        let v = max(0.0, min(100.0, value))

        // stops at 0.00, 0.39, 0.69, 1.00 (same as gradient)
        if v <= 39 {
            return mix(from: red, to: orange, t: v / 39.0)
        } else if v <= 69 {
            return mix(from: orange, to: yellow, t: (v - 39.0) / 30.0)
        } else {
            // note: 100 - 69 = 31; keep denominator > 0
            return mix(from: yellow, to: green, t: (v - 69.0) / 31.0)
        }
    }

    private static func mix(from a: Color, to b: Color, t: Double) -> Color {
        // Colors above are created from literals; we can re-create with known RGBs.
        func rgb(_ c: Color) -> (Double, Double, Double) {
            switch c {
            case red:    return (0.95, 0.30, 0.25)
            case orange: return (0.98, 0.60, 0.20)
            case yellow: return (0.98, 0.85, 0.25)
            default:     return (0.45, 0.85, 0.40) // green
            }
        }
        let (ar, ag, ab) = rgb(a)
        let (br, bg, bb) = rgb(b)
        let u = max(0.0, min(1.0, t))
        let r = ar + (br - ar) * u
        let g = ag + (bg - ag) * u
        let b = ab + (bb - ab) * u
        return Color(red: r, green: g, blue: b)
    }
}


// MARK: - Right-side axis (dynamic 0…yMax with step) — pixel aligned & ViewBuilder-safe
struct RightAxis: View {
    let yMax: Double
    let step: Double // usually 20

    private var ticks: [Double] {
        guard yMax > 0, step > 0 else { return [0] }
        let top = max(step, yMax)
        var out: [Double] = []
        var v: Double = 0
        while v <= top + 0.0001 { out.append(v); v += step }
        return out
    }

    @inline(__always)
    private func pixelAlignedY(_ y: CGFloat, scale: CGFloat) -> CGFloat {
        (floor(y * scale) + 0.5) / scale
    }

    @inline(__always)
    private func yPos(for tick: Double, height h: CGFloat, scale: CGFloat) -> CGFloat {
        let denom = max(yMax, step)
        let frac = CGFloat(min(1, max(0, tick / denom)))
        let baseY = h * (1.0 - frac)
        // keep the 0 tick flush with the bottom edge
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

                    // gridline
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)

                    // label
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



// MARK: - Slot model
public struct CalmScoreRangeSlot: Identifiable {
    public let id = UUID()
    /// If `range == nil` there is **no data** for the slot → show empty track only.
    public var range: ClosedRange<Double>?
    public var bottomLabel: String?

    public init(range: ClosedRange<Double>?, bottomLabel: String? = nil) {
        if let r = range {
            // we keep original 0…100 domain; scaling is handled by chart yMax
            self.range = max(0, r.lowerBound) ... min(100, r.upperBound)
        } else {
            self.range = nil
        }
        self.bottomLabel = bottomLabel
    }
}

// MARK: - Core chart
public struct CalmScoreRangeChart: View {
    public var slots: [CalmScoreRangeSlot]

    /// Space between columns.
    public var spacing: CGFloat
    /// Draw x label every Nth column.
    public var labelEvery: Int

    /// Show the right Y axis.
    public var showYAxisMarks: Bool
    /// Reserved width for the right axis.
    public var axisWidth: CGFloat
    /// Extra space between the last column and the axis so bars never touch the axis.
    public var axisGutter: CGFloat

    /// Dynamic Y scale (top of axis). Bars are scaled to this.
    public var yMax: Double
    /// Tick interval on Y axis (default = 20).
    public var yStep: Double

    /// If provided, only the first `filledCount` slots render ranges;
    /// trailing slots are empty tracks (future/no data). If nil, we auto-detect
    /// by finding the first slot with `range == nil`.
    public var filledCount: Int?

    public init(
        slots: [CalmScoreRangeSlot],
        spacing: CGFloat = 3,
        labelEvery: Int = 15,
        showYAxisMarks: Bool = false,
        axisWidth: CGFloat = 36,
        axisGutter: CGFloat = 10,
        yMax: Double = 100,
        yStep: Double = 20,
        filledCount: Int? = nil
    ) {
        self.slots = slots
        self.spacing = spacing
        self.labelEvery = max(1, labelEvery)
        self.showYAxisMarks = showYAxisMarks
        self.axisWidth = axisWidth
        self.axisGutter = axisGutter
        self.yMax = max(yStep, yMax)       // at least one step tall
        self.yStep = max(1, yStep)
        self.filledCount = filledCount
    }

    public var body: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let totalH = max(1, geo.size.height)

            // Reserve a label strip at bottom so x-labels never get clipped
            let labelH: CGFloat = 18
            let trackH = max(1, totalH - labelH)

            // ---- NEW: choose a "nice" step from the available pixel height ----
            let minTickSpacingPx: CGFloat = 22   // keep labels/grid readable
            let maxTicks = Int(floor(trackH / max(1, minTickSpacingPx)))
            let picked = chooseStepAndTop(rangeMax: yMax, maxTicks: maxTicks)
            let displayStep = max(1, picked.step)
            let displayTop  = max(displayStep, picked.top)    // axis top used for both axis & bar scaling


            // Reserve axis strip (plus gutter) on the right if enabled
            let reservedAxisW = showYAxisMarks ? (axisWidth + axisGutter) : 0
            let columnsW = max(1, totalW - reservedAxisW)

            // Column geometry
            let nCols = slots.count
            let nLayout = max(nCols, 1) // avoid /0 in geometry math
            let rawW = (columnsW - spacing * CGFloat(nLayout - 1)) / CGFloat(nLayout)
            let colW = max(6, floor(rawW)) // chunky bars
            let pitch = colW + spacing
            let used = CGFloat(nLayout) * colW + spacing * CGFloat(nLayout - 1)
            let sidePad = max(0, (columnsW - used) / 2.0)

            // Effective filled count (auto-detect if not provided)
            let autoFilled = slots.firstIndex(where: { $0.range == nil }) ?? nCols
            let filled = min(nCols, filledCount ?? autoFilled)

            ZStack(alignment: .topLeading) {
                // Columns & tracks
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(slots.enumerated()), id: \.1.id) { idx, slot in
                        ZStack(alignment: .bottom) {
                            // Track (rounded, full trackH)
                            RoundedRectangle(cornerRadius: colW / 2, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .frame(width: colW, height: trackH)

                            // Range (only if within filled, and slot has data)
                            if idx < filled, let r = slot.range {
                                // Clamp to [0, yMax] for display, then scale to trackH
                                let loV = CGFloat(min(max(0, r.lowerBound), displayTop))
                                let hiV = CGFloat(min(max(0, r.upperBound), displayTop))
                                let yLo = trackH * (1.0 - (loV / CGFloat(displayTop)))
                                let yHi = trackH * (1.0 - (hiV / CGFloat(displayTop)))
                                let rangeHeight = max(1, yLo - yHi)

                                let loRaw = Double(r.lowerBound)
                                let hiRaw = Double(r.upperBound)
                                let bottomColor = CalmScoreColors.color(for: loRaw)
                                let topColor    = CalmScoreColors.color(for: hiRaw)

                                RoundedRectangle(cornerRadius: colW / 2, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [bottomColor, topColor],
                                            startPoint: .bottom,
                                            endPoint: .top
                                        )
                                    )
                                    .frame(width: colW, height: rangeHeight)
                                    .offset(y: -(trackH - yLo)) // align to lower bound
                            }
                        }
                        .frame(width: colW, height: trackH, alignment: .bottom)
                    }
                }
                .padding(.leading, sidePad)
                .frame(width: columnsW, height: trackH, alignment: .bottomLeading)

                // X-axis label layer (separate so labels never get clipped or squeezed)
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

                // Right axis (dynamic ticks) with a gutter so bars never touch labels/grid
                if showYAxisMarks {
                    RightAxis(yMax: displayTop, step: displayStep)
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


// MARK: - Previews (demo-only)
private enum _Demo {
    static func ranges(count: Int, base: ClosedRange<Double> = 20...90, jitter: Double = 6) -> [ClosedRange<Double>] {
        guard count > 0 else { return [] }
        return (0..<count).map { i in
            let phase = Double(i) / Double(count)
            let center = base.lowerBound + (base.upperBound - base.lowerBound) * (0.35 + 0.30 * sin(phase * .pi * 2))
            let lo = max(0, center - jitter)
            let hi = min(100, center + jitter * (0.7 + 0.6 * cos(phase * .pi * 2)))
            return lo...max(lo+1, hi)
        }
    }
    static func slots(count: Int, every: Int, prefix: String = "") -> [CalmScoreRangeSlot] {
        let rs = ranges(count: count)
        return rs.enumerated().map { (idx, r) in
            let label = (idx % every == 0) ? "\(prefix)\(idx)" : nil
            return .init(range: r, bottomLabel: label)
        }
    }
}

struct CalmScoreRangeChart_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 60 columns (Hour) — pretend it's 8:56 (i.e., only first 56 slots have data)
            CalmScoreRangeChart(
                slots: _Demo.slots(count: 60, every: 15),
                spacing: 3,
                labelEvery: 15,
                showYAxisMarks: true,
                axisWidth: 36,
                axisGutter: 8,
                filledCount: 56
            )
            .frame(height: 260)
            .padding()
            .background(Color.black)
            .previewDisplayName("60 columns (Hour)")

            // 24 columns (Day)
            CalmScoreRangeChart(
                slots: _Demo.slots(count: 24, every: 6),
                spacing: 6,
                labelEvery: 6,
                showYAxisMarks: true,
                axisWidth: 36,
                axisGutter: 8
            )
            .frame(height: 260)
            .padding()
            .background(Color.black)
            .previewDisplayName("24 columns (Day)")

            // 31 columns (Month)
            CalmScoreRangeChart(
                slots: _Demo.slots(count: 31, every: 5),
                spacing: 6,
                labelEvery: 5,
                showYAxisMarks: true,
                axisWidth: 36,
                axisGutter: 8
            )
            .frame(height: 260)
            .padding()
            .background(Color.black)
            .previewDisplayName("31 columns (Month)")
        }
        .preferredColorScheme(.dark)
    }
}
