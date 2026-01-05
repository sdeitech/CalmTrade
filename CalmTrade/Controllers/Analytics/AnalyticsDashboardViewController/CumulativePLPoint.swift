//
//  CumulativePLPoint.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/11/25.
//


import SwiftUI

struct GrossCumulativePLChart: View {

    let items: [CumulativePLPoint]

    private let chartHeight: CGFloat = 200
    private let lineColor = Color(hex: 0x5DC866)
    private let spacing: CGFloat = 30
    private let tickCount = 5

    // MARK: Dynamic ranges
    var maxValue: Double { items.map { $0.value }.max() ?? 0 }
    var minValue: Double { items.map { $0.value }.min() ?? 0 }

    // Always include zero for context
    var displayMax: Double { max(maxValue, 0) }
    var displayMin: Double { min(minValue, 0) }

    // Dynamic ticks
    var yTicks: [Double] {
        guard tickCount > 1 else { return [displayMax, displayMin] }
        let range = displayMax - displayMin
        let step = range / Double(tickCount - 1)

        return (0..<tickCount).map { displayMax - (Double($0) * step) }
    }

    var body: some View {
        ZStack {
            backgroundCard
            HStack {
                yAxisLabels
                scrollableChart
            }
            .padding(.horizontal, 12)
        }
    }

    // MARK: Background Card
    private var backgroundCard: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(red: 0.12, green: 0.12, blue: 0.13))
            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
    }

    // MARK: Y-Axis
    private var yAxisLabels: some View {
        VStack(spacing: 0) {
            ForEach(yTicks, id: \.self) { tick in
                Text("$\(Int(tick))")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(width: 50)
    }

    // MARK: Scrollable chart
    private var scrollableChart: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            chartBody
                .frame(height: chartHeight)
        }
    }

    // MARK: Chart content
    private var chartBody: some View {
        ZStack {
            gridLines
            zeroLine
            linePath
            dateLabels
        }
    }

    // MARK: Grid Lines
    private var gridLines: some View {
        VStack(spacing: 0) {
            ForEach(yTicks, id: \.self) { _ in
                Rectangle()
                    .fill(Color.gray.opacity(0.22))
                    .frame(height: 1)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    // MARK: Zero horizontal line
    private var zeroLine: some View {
        VStack {
            Spacer(minLength: zeroLineOffset())
            Rectangle()
                .fill(Color.green.opacity(0.5))
                .frame(height: 2)
            Spacer()
        }
    }

    private func zeroLineOffset() -> CGFloat {
        let range = displayMax - displayMin
        guard range > 0 else { return chartHeight / 2 }
        let normalized = (0 - displayMin) / range
        return normalized * (chartHeight - 20)
    }

    // MARK: Line shape
    private var linePath: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let points = items

            Path { path in
                guard let first = points.first else { return }

                let startX: CGFloat = 0
                let startY = yPosition(for: first.value, height: height)

                path.move(to: CGPoint(x: startX, y: startY))

                for (index, point) in points.enumerated() {
                    let x = CGFloat(index) * spacing
                    let y = yPosition(for: point.value, height: height)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .trim(from: 0, to: 1)
            .stroke(lineColor, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        }
    }

    private func yPosition(for value: Double, height: CGFloat) -> CGFloat {
        let range = displayMax - displayMin
        guard range > 0 else { return height / 2 }

        let normalized = (value - displayMin) / range
        let offset = normalized * (height - 20)
        return height - offset
    }

    // MARK: X-Axis Date Labels
    private var dateLabels: some View {
        VStack {
            Spacer()
            HStack(spacing: spacing) {
                ForEach(items) { item in
                    Text(shortDate(item.date))
                        .foregroundColor(.gray)
                        .font(.caption2)
                        .frame(width: spacing * 1.5)
                }
            }
            .padding(.top, 8)
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

#Preview {
    let sampleDates = (0..<30).map {
        Calendar.current.date(byAdding: .day, value: -100 + $0, to: Date())!
    }
    let sampleValues: [Double] = sampleDates.enumerated().map { idx, _ in
        // Fake cumulative progression
        Double(idx * 10) - 200
    }
    

    let points = zip(sampleDates, sampleValues).map {
        CumulativePLPoint(date: $0, value: $1)
    }

    return GrossCumulativePLChart(items: points)
        .frame(height: 260)
        .padding()
        .background(Color.black)
}
