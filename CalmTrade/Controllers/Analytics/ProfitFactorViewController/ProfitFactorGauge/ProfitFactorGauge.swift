//
//  ProfitFactorGauge.swift
//  CalmTrade
//
//  Created by Anas Parekh on 08/12/25.
//

import SwiftUI

// MARK: - Dynamic Gradient Generator Based on Ratio
struct ProfitFactorGaugeColors {

    /// Creates a 4-stop gradient like WinRateGauge
    /// Example ratio 1:3 -> [green, red, red, red]
    static func gradient(win: Double, loss: Double) -> [Color] {

        let total = max(1, win + loss)

        let winRatio = win / total
        let lossRatio = loss / total

        let totalStops = 4.0

        let greenCount = Int(round(totalStops * winRatio))
        let redCount = Int(round(totalStops * lossRatio))

        var arr: [Color] = []

        for _ in 0..<greenCount { arr.append(.green) }
        for _ in 0..<redCount { arr.append(.red) }

        // ensure exactly 4 colors
        while arr.count < 4 { arr.append(.red) }
        if arr.count > 4 { arr = Array(arr.prefix(4)) }

        return arr
    }
}

// MARK: - Main Gauge
struct ProfitFactorGauge: View {
    let percent: Double               // pointer position (0…100)
    let winValue: Double              // RIGHT SIDE: wins (positive)
    let lossValue: Double             // RIGHT SIDE: losses (positive)
    
    private var clamped: Double { min(100, max(0, percent)) }

    var body: some View {
        GaugeBarPF(score: clamped,
                   winValue: winValue,
                   lossValue: lossValue)
            .frame(height: 36)
            .padding(16)
    }
}

// MARK: - Bar (IDENTICAL TO WinRateGauge BUT WITH DYNAMIC COLORS)
private struct GaugeBarPF: View {
    let score: Double          // pointer (0..100)
    let winValue: Double
    let lossValue: Double      // use abs(loss)

    var body: some View {
        HStack {
            ZStack {
                GeometryReader { geo in

                    let w = geo.size.width
                    let h = geo.size.height
                    let radius = h / 2
                    let x = CGFloat(score / 100.0) * w

                    // dynamic gradient
                    let gradientColors = ProfitFactorGaugeColors.gradient(
                        win: winValue,
                        loss: lossValue
                    )

                    let pointerColor = gradientColors.last ?? .white

                    // BAR (same as WinRateGauge)
                    RoundedRectangle(cornerRadius: radius)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: gradientColors),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: radius)
                                .stroke(Color.white.opacity(0.15), lineWidth: 2)
                        )

                    // Vertical pointer line
                    Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: h))
                    }
                    .stroke(.black, lineWidth: 3)

                    // Bubble (same as WinRateGauge)
                    RateBubble(score: Int(score), color: pointerColor)
                        .position(x: x, y: h/2)
                        .offset(y: -(h/2 + 25))

                    // Triangle (same as WinRateGauge)
                    Triangle()
                        .fill(pointerColor)
                        .frame(width: 16, height: 16)
                        .position(x: x, y: h/2)
                        .offset(y: h/2 + 10)
                }
            }
            .frame(height: 20)
        }
    }
}
