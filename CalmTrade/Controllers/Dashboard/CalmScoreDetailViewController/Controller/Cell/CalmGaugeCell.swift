//
//  CalmGaugeCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 11/09/25.
//

import UIKit
import SwiftUI

// MARK: - UICollectionViewCell hosting a SwiftUI card
final class CalmGaugeCell: UICollectionViewCell {
    static let reuseId = "CalmGaugeCell"

    private var host: UIHostingController<CalmHistoryCard>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }

    private func build() {
        // Match the soft, rounded card look
        contentView.layer.cornerCurve = .continuous
        contentView.layer.cornerRadius = 20
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .black

        // Add once; we'll set the real rootView in configure(_:).
        let initial = CalmHistoryCard(title: "—", score: 0)
        let hosting = UIHostingController(rootView: initial)
        hosting.view.backgroundColor = .clear

        host = hosting
        contentView.addSubview(hosting.view) // (you already fixed this in your latest file)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        host?.rootView = CalmHistoryCard(title: "—", score: 0)
    }

    func configure(_ item: CalmHistoryItem) {
        host?.rootView = CalmHistoryCard(title: item.title, score: item.average)
        host?.view.backgroundColor = .clear
        contentView.backgroundColor = .black
    }
}

// MARK: - SwiftUI Card (replicates your Figma)
struct CalmHistoryCard: View {
    let title: String
    /// 0…100
    let score: Double

    private var clampedScore: Double { min(100, max(0, score)) }
    private var progress: CGFloat { CGFloat(clampedScore / 100.0) }

    var body: some View {
        ZStack {
            // Card background with subtle inner shadow-ish overlay
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(cgColor: UIColor.init("1C1C1F").cgColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    ScoreBadge(score: clampedScore)
                }

                GaugeBar1(score: clampedScore)
                    .frame(height: 36)

                Spacer(minLength: 4)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(16)
        }
        .background(Color.clear)
    }
}

// MARK: - Score badge (top-right)
private struct ScoreBadge: View {
    let score: Double
    var body: some View {
        let c = GaugeColors.color(for: score)
        Text("\(Int(round(score)))")
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
            Text("S")
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
//                    ScoreBubble(score: Int(round(clamped)), color: pointerColor)
//                        .position(x: x, y: h/2)
//                        .offset(y: -(h/2 + 34))   // tweak 22–32 to taste
                    
                    // triangle below the bar
                    Triangle()
                        .fill(pointerColor)
                        .frame(width: 16, height: 16)
                        .position(x: x, y: h/2)
                        .offset(y: h/2 + 10)

                }
            }
            .frame(height: 20) // keep your target height

            Text("C")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.calmGreen)
        }
    }
}

// MARK: - Small triangle shape for the pointer
private struct Triangle1: Shape {
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
        CalmHistoryCard(title: "Yesterday", score: 100)
            .frame(width: 170, height: 170)
            .preferredColorScheme(.dark)

        CalmHistoryCard(title: "5 June 2025", score: 55)
            .frame(width: 170, height: 170)
            .preferredColorScheme(.dark)
    }
    .padding()
    .background(Color.black)
}
#endif
