//
//  CalmLineChart.swift
//  CalmTrade
//
//  Created by Anas Parekh on 11/09/25.
//

import SwiftUI
import Charts

// MARK: - Model shown by the chart
struct CalmPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let value: Double     // 0...100
}

// MARK: - Chart
struct CalmLineChart: View {
    let points: [CalmPoint]

    // Tap/drag selection (optional)
    @State private var selected: CalmPoint?

    init(points: [CalmPoint]) {
        self.points = points
        // Default selection: the lowest value (matches your screenshot case)
        _selected = State(initialValue: points.min(by: { $0.value < $1.value }))
    }

    var body: some View {
        Chart {
            // Dots only
            ForEach(points) { p in
                PointMark(
                    x: .value("Time", p.date),
                    y: .value("Calm", p.value)
                )
                .symbolSize(80)
                .foregroundStyle(color(for: p.value))

                // Bubble annotation for the selected point
                if p == selected {
                    PointMark(
                        x: .value("Time", p.date),
                        y: .value("Calm", p.value)
                    )
                    .annotation(position: .top, spacing: 8) {
                        BubbleLabel(text: Int(p.value).formatted())
                    }
                }
            }

            // Optional baseline at y = 0 to make the bottom border feel solid
            RuleMark(y: .value("Zero", 0))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(.white.opacity(1.0))
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(points.count, 8))) { value in
                AxisGridLine()
                    .foregroundStyle(.white.opacity(1.0))      // (no .lineStyle on iOS 16)
                AxisTick().foregroundStyle(.white)
                AxisValueLabel {
                    if let d = value.as(Date.self) {
                        Text(d, format: .dateTime
                            .hour(.defaultDigits(amPM: .abbreviated))
                            .minute(.twoDigits))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.9))
            }
        }
        .chartYAxis {
            // Trailing y-axis: 0, 25, 50, 100 like the screenshot
            AxisMarks(values: [0, 25, 50, 100]) { v in
                AxisGridLine().foregroundStyle(.white) // no horizontal grid lines
                AxisTick().foregroundStyle(.white)
                AxisValueLabel {
                    if let num = v.as(Double.self) {
                        Text("\(Int(num))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
        }
        .chartYAxis(.visible)
        .chartPlotStyle { plot in
            plot
                .background(Color.black)          // plot area
                .overlay(
                    // bottom & right border to mimic your mock
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle().fill(Color.white.opacity(1.0)).frame(height: 1)
                    }
                )
        }
        .padding(.vertical, 8)
        .background(Color.black)                   // outside the plot area
        .contentShape(Rectangle())
        // Tap/drag to update the callout
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x - geo[proxy.plotFrame!].origin.x
                                if let date: Date = proxy.value(atX: x) {
                                    selected = nearestPoint(to: date)
                                }
                            }
                            .onEnded { _ in }
                    )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selected)
    }

    // MARK: - Helpers

    private func color(for v: Double) -> Color {
        v < 50 ? Color.orange : Color.green
    }

    private func nearestPoint(to date: Date) -> CalmPoint? {
        guard !points.isEmpty else { return nil }
        return points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
}

// MARK: - Bubble label like “25” with a small pointer
private struct BubbleLabel: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.gray.opacity(0.9))
                )
            TrianglePointer()
                .fill(Color.gray.opacity(0.9))
                .frame(width: 12, height: 6)
                .offset(y: -1)
        }
    }
}

private struct TrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}



#if DEBUG
struct CalmLineChart_Previews: PreviewProvider {
    static var previews: some View {
        let demo: [CalmPoint] = (0..<6).map { i in
            CalmPoint(date: Date().addingTimeInterval(Double(i) * 60),
                      value: Double(Int.random(in: 20...95)))
        }
        return CalmLineChart(points: demo)
            .frame(height: 200)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
