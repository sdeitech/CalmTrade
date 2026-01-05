//
//  WinRateGauge.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/11/25.
//

import SwiftUI

struct WinRateGaugeColors {
    static let gradientColors: [Color] = [Color(hex: 0xF4B04C),Color(hex: 0xF4B04C),Color(hex: 0x39662E), Color(hex: 0x245E2B)]
    
    /// Returns the interpolated color in the gradient at a given score (0...100)
    static func color(for score: Double) -> Color {
        let clamped = max(0, min(100, score))
        let t = clamped / 100.0
        let pos = t * Double(gradientColors.count - 1)
        
        let i0 = min(gradientColors.count - 2, Int(floor(pos)))
        let i1 = min(gradientColors.count - 1, Int(ceil(pos)))
        
        let c0 = UIColor(gradientColors[i0])
        let c1 = UIColor(gradientColors[i1])
        
        var r0: CGFloat = 0, g0: CGFloat = 0, b0: CGFloat = 0, a0: CGFloat = 0
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        c0.getRed(&r0, green: &g0, blue: &b0, alpha: &a0)
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        
        let f = pos - Double(i0)
        let r = r0 + (r1 - r0) * f
        let g = g0 + (g1 - g0) * f
        let b = b0 + (b1 - b0) * f
        
        return Color(red: r, green: g, blue: b)
    }
}

struct WinRateGauge: View {
//    let title: String
    /// 0…100
    let score: Double

    private var clampedScore: Double { min(100, max(0, score)) }
    private var progress: CGFloat { CGFloat(clampedScore / 100.0) }

    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack {
//                Spacer()
//                ScoreBadge(score: clampedScore)
//            }
            
            GaugeBar1(score: clampedScore)
                .frame(height: 36)
//        }
        .padding(16)
    }
}

// MARK: - Score badge (top-right)
private struct ScoreBadge: View {
    let score: Double
    var body: some View {
        let c = WinRateGaugeColors.color(for: score)
        Text("\(Int(round(score)))%")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(c)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(c, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.4))
                    )
            )
    }
}

// MARK: - Gradient bar with “Stress/Calm” labels and pointer
private struct GaugeBar1: View {
    var score: Double   // 0...100

    var body: some View {
        HStack {
            ZStack {
                GeometryReader { geo in
                    // The bar itself
                    let w = geo.size.width
                    let h = geo.size.height
                    let radius = h / 2
                    let clamped = min(max(score, 0), 100)
                    let x = CGFloat(clamped / 100.0) * w
                    let pointerColor = WinRateGaugeColors.color(for: clamped)

                    // BAR
                    RoundedRectangle(cornerRadius: radius, style: .circular)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: WinRateGaugeColors.gradientColors),
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 2)
                        )

                    // 1) vertical dash spanning the bar
                    Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: h))
                    }.stroke(.black, lineWidth: 3)
                    
                    // bubble a bit higher
                    RateBubble(score: Int(round(clamped)), color: pointerColor)
                        .position(x: x, y: h/2)
                        .offset(y: -(h/2 + 25))   // tweak 22–32 to taste
                    
                    // triangle below the bar
                    Triangle()
                        .fill(pointerColor)
                        .frame(width: 16, height: 16)
                        .position(x: x, y: h/2)
                        .offset(y: h/2 + 10)

                }
            }
            .frame(height: 20) // keep your target height
        }
    }
}

struct RateBubble: View {
    var score: Int
    var color: Color
    
    var body: some View {
        Text("\(score)")
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color, lineWidth: 3)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0)))
            )
            .accessibilityIdentifier("scoreBubble")
            .aspectRatio(1, contentMode: .fill)
    }
}

// MARK: - Small triangle shape for the pointer
struct Triangle2: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Preview
#if DEBUG
import SwiftUI
#Preview("Calm History Card") {
    Group {
        WinRateGauge(score: 34)
            .frame(width: 170, height: 170)
            .preferredColorScheme(.dark)

//        WinRateGauge(title: "50", score: 55)
//            .frame(width: 170, height: 170)
//            .preferredColorScheme(.dark)
    }
    .padding()
    .background(Color.black)
}
#endif
