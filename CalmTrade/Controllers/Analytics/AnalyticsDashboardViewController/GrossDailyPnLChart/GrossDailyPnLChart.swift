//
//  GrossDailyPnLChart.swift
//  CalmTrade
//

import SwiftUI

struct GrossDailyPnLChart: View {

    let items: [DailyPnLBar]

    // MARK: - State
    @State private var selectedIndex: Int?
    @State private var animateBars = false
    @State private var yZoom: CGFloat = 1.0
    @State private var xZoom: CGFloat = 1.0

    // MARK: - Constants
    private let baseChartHeight: CGFloat = 170
    private let baseBarWidth: CGFloat = 10
    private let spacing: CGFloat = 6
    private let tickCount = 5

    // MARK: - Derived
    private var safeItems: [DailyPnLBar] { items }

    /// Largest absolute value in data, with a minimum visual range so tiny values don't explode
    private var maxAbsValue: Double {
        let maxV = safeItems.map { abs($0.value) }.max() ?? 0
        return max(maxV, 0.5) // you can tweak 0.5 → 1.0, etc.
    }

    /// Symmetric around zero for financial-style chart
    private var displayedMax: Double { maxAbsValue }
    private var displayedMin: Double { -maxAbsValue }

    /// Ticks: +max, +half, 0, -half, -max
    private var yTicks: [Double] {
        guard tickCount > 1 else { return [displayedMax, 0, displayedMin] }

        let half = tickCount / 2         // e.g. 5 → 2
        let step = maxAbsValue / Double(half)

        // For 5 ticks: +max, +max/2, 0, -max/2, -max
        return (0..<tickCount).map { idx in
            displayedMax - Double(idx) * step
        }
    }

    private var barAreaHeight: CGFloat {
        (baseChartHeight - 30) * yZoom
    }

    // MARK: - View
    var body: some View {
        HStack(spacing: 4) {

            // Y Axis labels
            VStack(spacing: 0) {
                ForEach(yTicks, id: \.self) { tick in
                    Text("$\(formatTick(tick))")
                        .foregroundColor(Color(uiColor: UIColor("7D7779")))
                        .font(.custom("Helvetica-Medium", size: 8))
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            }
            .frame(width: 50)

            // Scrollable chart + pinch zoom
            ScrollView(.horizontal, showsIndicators: false) {
                chartBody
                    .frame(height: baseChartHeight)
                    .gesture(zoomGesture)
            }
        }
        .background(Color.clear)
        .onAppear { animateBars = true }
    }

    // MARK: - Chart Body
    private var chartBody: some View {
        ZStack {
            gridLines
            bars
            zeroLine
            tooltip
        }
    }

    // MARK: - Grid Lines
    private var gridLines: some View {
        VStack(spacing: 0) {
            ForEach(yTicks, id: \.self) { _ in
                Rectangle()
                    .fill(Color(uiColor: UIColor("242832")))
                    .frame(height: 1)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    // MARK: - Bars (centered on zero line)
    private var bars: some View {
        let barWidth = baseBarWidth * xZoom

        return HStack(alignment: .center, spacing: spacing) {
            ForEach(safeItems.indices, id: \.self) { index in
                let item = safeItems[index]
                let isSel = selectedIndex == index
                let barH = barHeight(from: item.value)

                VStack(spacing: 3) {
                    // Container whose vertical center is the zero line
                    ZStack {
                        if item.value > 0 {
                            Rectangle()
                                .fill(isSel
                                      ? Color(uiColor: UIColor("56B073"))
                                      : Color(uiColor: UIColor("56B073")).opacity(0.7))
                                .frame(width: barWidth, height: barH)
                                .offset(y: -barH / 2)   // above zero
                        } else if item.value < 0 {
                            Rectangle()
                                .fill(isSel
                                      ? Color(uiColor: UIColor("B52D0B"))
                                      : Color(uiColor: UIColor("B52D0B")).opacity(0.7))
                                .frame(width: barWidth, height: barH)
                                .offset(y: barH / 2)    // below zero
                        }
                        // value == 0 → no bar
                    }
                    .frame(width: barWidth, height: barAreaHeight, alignment: .center)
                    .contentShape(Rectangle())
                    .scaleEffect(isSel ? 1.1 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSel)
                    .onTapGesture { selectedIndex = index }

                    // Date label
                    Text(dateLabel(item.date))
                        .foregroundColor(Color(uiColor: UIColor("7D7779")))
                        .font(.custom("Helvetica-Medium", size: 8))
                        .frame(width: barWidth * 3)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: - Zero Line (always center of bar area)
    private var zeroLine: some View {
        VStack {
            Spacer()
                .frame(height: barAreaHeight / 2)
            Rectangle()
                .fill(Color.green.opacity(0.7))
                .frame(height: 2)
            Spacer()
                .frame(height: barAreaHeight / 2)
        }
    }

    // MARK: - Tooltip
    private var tooltip: some View {
        GeometryReader { geo in
            if let index = selectedIndex,
               index < safeItems.count {

                let item = safeItems[index]
                let barH = barHeight(from: item.value)
                let centerY = geo.size.height / 2

                // Compute Y *outside* of the View expression
                let tooltipY: CGFloat = {
                    if item.value >= 0 {
                        return max(centerY - barH - 20, 18)
                    } else {
                        return max(centerY - 20, 18)
                    }
                }()

                VStack(spacing: 4) {
                    Text("$\(formatTick(item.value))")
                        .font(.caption2.bold())
                        .foregroundColor(item.value >= 0 ? .green : .red)

                    Text(dateLabel(item.date))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(8)
                .background(Color.black.opacity(0.85))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.18))
                )
                .position(
                    x: tooltipX(in: geo.size, index: index),
                    y: tooltipY   // <-- now safe
                )
                .animation(.easeInOut(duration: 0.25), value: selectedIndex)
            }
        }
    }

    // MARK: - Tooltip Position Helpers
    private func tooltipX(in size: CGSize, index: Int) -> CGFloat {
        CGFloat(index) * ((baseBarWidth * xZoom) + spacing) + (baseBarWidth * xZoom / 2)
    }

    // MARK: - Bar Height (relative to |max|)
    private func barHeight(from value: Double) -> CGFloat {
        if abs(value) < 0.000001 { return 0 }   // zero → no bar

        let normalized = abs(value) / maxAbsValue
        return normalized * barAreaHeight
    }

    // MARK: - Zoom Gesture
    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                let delta = scale - 1

                if abs(delta) > 0.01 {
                    if delta > 0 {
                        yZoom = min(yZoom + delta * 0.4, 4)
                        xZoom = min(xZoom + delta * 0.2, 4)
                    } else {
                        yZoom = max(yZoom + delta * 0.4, 0.4)
                        xZoom = max(xZoom + delta * 0.2, 0.4)
                    }
                }
            }
    }

    // MARK: - Helpers
    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "MM-dd"
        return f.string(from: date)
    }

    private func formatTick(_ value: Double) -> String {
        let absVal = abs(value)
        if absVal >= 1 {
            return String(format: "%.2f", value)
        } else {
            return String(format: "%.3f", value)
        }
    }
}

// MARK: - PREVIEW
struct GrossDailyPnLChart_Previews: PreviewProvider {
    static var previews: some View {
        let sample: [DailyPnLBar] = [
            .init(date: Date(), value: -0.07),
            .init(date: Date().addingTimeInterval(86400), value: 0.02),
            .init(date: Date().addingTimeInterval(2*86400), value: 0),
        ]

        return GrossDailyPnLChart(items: sample)
            .frame(height: 170)
            .background(Color.black)
            .previewLayout(.sizeThatFits)
    }
}
