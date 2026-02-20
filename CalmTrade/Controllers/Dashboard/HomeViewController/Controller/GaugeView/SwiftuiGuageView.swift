//
//  SwiftuiGuageView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 08/09/25.
//

import SwiftUI

struct GaugeBarFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Model
enum DeviceSource: String, CaseIterable {
    case appleHK = "Apple HK"
    case h10 = "H10"
    case calm360 = "Calm360"
    case connect = "Connect"     // 👈 NEW
    var displayName: String { rawValue }
}
struct TrendData: Equatable {
    var hrvMs: Double
    var hrvIsUp: Bool
    var hrBpm: Double
    var hrIsDown: Bool
    var sleepHours: Double
    var sleepIsUp: Bool
}
struct CalmScoreTileProps: Equatable {
    var score: Double          // 0...100
    var lastUpdate: Date
    var deviceSource: DeviceSource
    var isStreaming: Bool
    var trend: TrendData
    var batteryPercent: Double?
}

// MARK: - Colors
extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
    static let neonMint = Color(hex: 0x00FFC3)
    static let stressRed = Color(hex: 0xFF4D3D)
    static let calmGreen  = Color(hex: 0x00C96B)
    static let gaugeYellow = Color(hex: 0xE2C74E)
    static let bgBlack = Color(hex: 0x0F1115)
    static let greyText = Color.white.opacity(0.85)
}

// MARK: - Color Helper for Gradient
struct GaugeColors {
    static let gradientColors: [Color] = [.stressRed, .orange, .gaugeYellow, .calmGreen]
    
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

// MARK: - Main View
struct CalmScoreBarTile: View {
    var props: CalmScoreTileProps
    var onConnectTap: (() -> Void)? = nil
    var onTileTap:   (() -> Void)? = nil
    
    @State private var gaugeBarFrame: CGRect = .zero
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer()

            // Top row: last update + device pill
            HStack(alignment: .center) {
                Text(Self.format(date: props.lastUpdate))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.greyText)
                    .accessibilityIdentifier("lastUpdateLabel")
                Spacer()
                DevicePill(
                    source: props.deviceSource,
                    isStreaming: props.isStreaming,
                    onTapConnect: onConnectTap
                )
            }
            .padding(.bottom, 56)

            GaugeBar(score: props.score)
                .frame(height: 36)
                .padding(.top, 30)

            TrendRow(trend: props.trend)
                .padding(.top, 18)

            HStack {
                Spacer()
                Text("CalmScore")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 8)
                Spacer()
            }

            Spacer()
        }
        .padding(20)
        .background(Color.clear)
        .contentShape(Rectangle())             // 👈 make whole tile tappable
        .onTapGesture { onTileTap?() }         // 👈 tile tap callback
        .coordinateSpace(name: "container")
    }
    
    private static func format(date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "'Last update' M/d/yyyy HH:mm:ss zzz"
        return df.string(from: date)
    }
}

// MARK: - Device Pill
struct DevicePill: View {
    var source: DeviceSource
    var isStreaming: Bool
    var onTapConnect: (() -> Void)? = nil
    var body: some View { Button(action: { if source == .connect { onTapConnect?() } }) { HStack(spacing: 6) { // UPDATED smaller spacing
        Circle() .fill(isStreaming ? Color.green : Color.gray) .frame(width: 6, height: 6) // UPDATED smaller dot
        Text(source.displayName)
            .font(.system(size: 12, weight: .semibold, design: .rounded)) // UPDATED smaller font
        .foregroundColor(.greyText) }
    .padding(.horizontal, 10) // UPDATED smaller
    .padding(.vertical, 5) // UPDATED smaller
    .background(
        RoundedRectangle(cornerRadius: 14)
            .stroke(Color.greyText.opacity(0.30), lineWidth: 0.8) // UPDATED thinner stroke
            .fill(isStreaming ? Color.white
                .opacity(0.05) : Color.clear) )
        .accessibilityIdentifier("devicePill") }
    .buttonStyle(.plain) // 👈 keep pill styling
    .disabled(source != .connect) // 👈 only interactive for Connect
    .opacity(source == .connect ? 1.0 : 0.8)
    }
}
    
    
    
    // MARK: - Gauge Bar + Pointer
    struct GaugeBar: View {
        var score: Double   // 0...100
        
        var body: some View {
            HStack {
                Text("Stress")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.stressRed)
                
                ZStack {
                    GeometryReader { geo in
                        // The bar itself
                        let h = geo.size.height
                        let w = geo.size.width
                        let radius = h / 2
                        let clamped = min(max(score, 0), 100)
                        let x = CGFloat(clamped / 100.0) * w
                        let pointerColor = GaugeColors.color(for: clamped)
                        
                        // BAR
                        RoundedRectangle(cornerRadius: radius, style: .circular)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: GaugeColors.gradientColors),
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
                        ScoreBubble(score: Int(round(clamped)), color: pointerColor)
                            .position(x: x, y: h/2)
                            .offset(y: -(h/2 + 34))   // tweak 22–32 to taste
                        
                        // triangle below the bar
                        Triangle()
                            .fill(pointerColor)
                            .frame(width: 16, height: 16)
                            .position(x: x, y: h/2)
                            .offset(y: h/2 + 10)
                        
                    }
                }
                .frame(height: 36) // keep your target height
                
                Text("Calm")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.calmGreen)
            }
        }
    }
    
    
    struct GaugePointer: View {
        var score: Double
        var gaugeFrame: CGRect
        
        var body: some View {
            let clamped = min(max(score, 0), 100)
            let x = gaugeFrame.minX + (clamped / 100.0) * gaugeFrame.width
            
            let pointerColor = GaugeColors.color(for: clamped)
            
            ZStack {
                // Vertical line spanning the gauge bar fully
                Path { path in
                    path.move(to: CGPoint(x: x, y: gaugeFrame.minY))
                    path.addLine(to: CGPoint(x: x, y: gaugeFrame.maxY))
                }
                .stroke(.black, lineWidth: 3)   // keep black or change to pointerColor if you want it dynamic
                .opacity(0.9)
                
                // Score bubble - closer to gauge bar
                ScoreBubble(score: Int(round(clamped)), color: pointerColor)
                    .position(x: x, y: gaugeFrame.minY - 280) // UPDATED: reduced offset (was -180)
                
                // Triangle pointer just below the bar
                Triangle()
                    .fill(pointerColor)
                    .frame(width: 18, height: 18)
                    .position(x: x, y: gaugeFrame.maxY + 12) // UPDATED: align right under bar
            }
        }
    }
    
    
    struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
            return p
        }
    }
    
    struct ScoreBubble: View {
        var score: Int
        var color: Color
        
        var body: some View {
            Text("\(score)")
                .font(.system(size: 35, weight: .bold, design: .rounded))
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
    
    // MARK: - Trend Row
    struct TrendRow: View {
        var trend: TrendData
        var body: some View {
            HStack(spacing: 6) {
                Spacer()
                //            Text("Trend:")
                //                .font(.system(size: 12, weight: .semibold, design: .rounded))
                //                .foregroundColor(.greyText)
                
                // HRV (triangle icon REMOVED)
                Text("HRV")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.greyText)
                Text("\(trend.hrvIsUp ? "↑" : "↓") \(Int(round(trend.hrvMs))) ms")
                    .foregroundColor(trend.hrvIsUp ? .green : .red)
                    .font(.system(size: 16, weight: .light, design: .rounded))
                
                Divider().frame(height: 14).background(Color.white.opacity(0.2))
                
                // HR (triangle icon REMOVED; keep ↓/↑ text with correct green rule)
                Text("HR")
                    .foregroundColor(.greyText)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                Text("\(trend.hrIsDown ? "↓" : "↑") \(Int(round(trend.hrBpm))) bpm")
                    .foregroundColor(trend.hrIsDown ? .green : .red)
                    .font(.system(size: 16, weight: .light, design: .rounded))
                
                Divider().frame(height: 14).background(Color.white.opacity(0.2))
                
                // Sleep (triangle icon REMOVED)
                Text("Sleep")
                    .foregroundColor(.greyText)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                Text("\(trend.sleepIsUp ? "↑" : "↓") \(Self.formatSleepHours(trend.sleepHours))")
                    .foregroundColor(trend.sleepIsUp ? .green : .red)
                    .font(.system(size: 16, weight: .light, design: .rounded))
                
                Spacer()
            }
            //.font(.system(size: 20, weight: .regular, design: .rounded))
        }

        private static func formatSleepHours(_ hours: Double) -> String {
            let totalMinutes = Int((hours * 60.0).rounded())
            let h = totalMinutes / 60
            let m = totalMinutes % 60
            return "\(h)h \(m)m"
        }
    }
    
    // (Helper used only before; keeping for compatibility if needed elsewhere)
    struct DirectionArrow: View {
        var up: Bool
        var body: some View {
            // REMOVED from UI usages — kept here to avoid breaking previews/imports.
            Image(systemName: "triangle.fill")
                .font(.system(size: 5, weight: .bold))
                .rotationEffect(.degrees(up ? 0 : 180))
                .foregroundColor(up ? .green : .red)
                .hidden()
        }
    }
    
    // MARK: - Previews
    struct CalmScoreBarTile_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                preview(for: .appleHK, isStreaming: true, score: 100)
                    .previewDisplayName("High Score")
                preview(for: .h10, isStreaming: true, score: 70)
                    .previewDisplayName("Medium Score")
                preview(for: .calm360, isStreaming: true, score: 15)
                    .previewDisplayName("Low Score")
                preview(for: .appleHK, isStreaming: false, score: 70)
                    .previewDisplayName("Fallback")
            }
            .previewLayout(.sizeThatFits)
            .background(Color.black)
        }
        
        static func preview(for src: DeviceSource, isStreaming: Bool, score: Double) -> some View {
            let props = CalmScoreTileProps(
                score: score,
                lastUpdate: Date(),
                deviceSource: .calm360,
                isStreaming: isStreaming,
                trend: TrendData(hrvMs: 72, hrvIsUp: true, hrBpm: 64, hrIsDown: true, sleepHours: 7.2, sleepIsUp: true),
                batteryPercent: 20
            )
            return CalmScoreBarTile(props: props)
                .frame(width: 820, height: 380)
        }
    }
