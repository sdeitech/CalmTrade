//
//  SleepScoreViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/03/26.
//


import Foundation
import UIKit

final class SleepScoreViewModel {
    
    enum Mode {
        case daily
        case weekly
    }
    
    var mode: Mode = .daily
    
    private(set) var dailyModel: SleepScoreDayModel?
    private(set) var weeklyModels: [SleepScoreDayModel] = []
    
    func loadData(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            let repo = SleepRepository.shared
            let now = Date()
            let lookbackStart = Calendar.current.date(byAdding: .day, value: -21, to: now) ?? now.addingTimeInterval(-21 * 86400)
            
            let preferredSource: SleepDataSource = {
                switch DeviceManager.shared.currentSource {
                case .polar360, .polarH10: return .ct360
                case .appleHealthKit: return .appleHealth
                }
            }()
            
            var sessions = repo
                .unifiedSessions(from: lookbackStart, to: now)
                .sorted { $0.sessionEnd > $1.sessionEnd }
            
            let preferredSessions = sessions.filter { $0.source == preferredSource }
            if !preferredSessions.isEmpty {
                sessions = preferredSessions
            }
            
            let models = sessions.compactMap { self.makeModel(from: $0) }
            let daily = models.first
            let weekly = Array(models.prefix(7))
            
            DispatchQueue.main.async {
                self.dailyModel = daily
                self.weeklyModels = weekly
                completion?()
            }
            
            private static let sleepScoreRingViewTag = 98_421
            
            // MARK: - Mock Loader (Replace with real data later)
            
            func loadData() {
                let today = Date()
                
                dailyModel = SleepScoreDayModel(
                    date: today,
                    score: 88,
                    amount: 0.8,
                    solidity: 0.7,
                    regeneration: 0.9,
                    rem: 0.6,
                    deep: 0.75
                )
                
                weeklyModels = (0..<6).map {
                    SleepScoreDayModel(
                        date: Calendar.current.date(byAdding: .day, value: -$0, to: today)!,
                        score: Int.random(in: 60...95),
                        amount: CGFloat.random(in: 0.4...1),
                        solidity: CGFloat.random(in: 0.4...1),
                        regeneration: CGFloat.random(in: 0.4...1),
                        rem: CGFloat.random(in: 0.4...1),
                        deep: CGFloat.random(in: 0.4...1)
                    )
                }
            }
            
            func numberOfItems() -> Int {
                switch mode {
                case .daily: return dailyModel == nil ? 0 : 2
                case .weekly: return weeklyModels.count
                }
            }
            
            func model(at index: Int) -> SleepScoreDayModel? {
                switch mode {
                case .daily:
                    return dailyModel
                case .weekly:
                    return weeklyModels[index]
                }
            }
            
            private func makeModel(from session: SleepSessionSummary) -> SleepScoreDayModel? {
                guard let computed = SleepScoreCalculator.calculate(segments: session.segments, sleepGoalMinutes: 480) else {
                    return nil
                }
                
                return SleepScoreDayModel(
                    date: session.sessionEnd,
                    score: computed.totalScore,
                    sleepTimeMinutes: computed.sleepTimeMinutes,
                    amountScore: computed.sleepAmount.score,
                    solidityScore: computed.sleepSolidity.score,
                    regenerationScore: computed.sleepRegeneration.score,
                    interruptionsScore: computed.interruptionsScore,
                    continuityScore: computed.continuityScore,
                    sleepEfficiencyScore: computed.sleepEfficiencyScore,
                    remScore: computed.remScore,
                    deepScore: computed.deepScore,
                    coreScore: computed.coreScore,
                    amount: CGFloat(Double(computed.sleepAmount.score) / Double(computed.sleepAmount.maxScore)),
                    solidity: CGFloat(Double(computed.sleepSolidity.score) / Double(computed.sleepSolidity.maxScore)),
                    regeneration: CGFloat(Double(computed.sleepRegeneration.score) / Double(computed.sleepRegeneration.maxScore)),
                    rem: CGFloat(Double(computed.remScore) / 12.0),
                    deep: CGFloat(Double(computed.deepScore) / 12.0),
                    core: CGFloat(Double(computed.coreScore) / 6.0)
                )
                
                @discardableResult
                static func makeSleepScoreRing(
                    in containerView: UIView,
                    score: Int,
                    centerFontSize: CGFloat
                ) -> UIView {
                    if let ringView = containerView.viewWithTag(sleepScoreRingViewTag) as? SleepScoreRingContainerView {
                        ringView.configure(score: score, centerFontSize: centerFontSize)
                        return ringView
                    }
                    
                    let ringView = SleepScoreRingContainerView()
                    ringView.tag = sleepScoreRingViewTag
                    ringView.translatesAutoresizingMaskIntoConstraints = false
                    
                    containerView.addSubview(ringView)
                    
                    NSLayoutConstraint.activate([
                        ringView.topAnchor.constraint(equalTo: containerView.topAnchor),
                        ringView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                        ringView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                        ringView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
                    ])
                    
                    ringView.configure(score: score, centerFontSize: centerFontSize)
                    return ringView
                }
            }
        }
    }
            
    private final class SleepScoreRingContainerView: UIView {
        
        private struct SegmentLayerSet {
            let trackLayer = CAShapeLayer()
            let progressLayer = CAShapeLayer()
            let gradientLayer = CAGradientLayer()
        }
        
        private let scoreLabel = UILabel()
        private let segmentColors: [[UIColor]] = [
            [
                UIColor(red: 0.20, green: 0.90, blue: 0.92, alpha: 1.0),
                UIColor(red: 0.08, green: 0.47, blue: 0.48, alpha: 1.0)
            ],
            [
                UIColor(red: 0.99, green: 0.62, blue: 0.24, alpha: 1.0),
                UIColor(red: 0.39, green: 0.22, blue: 0.07, alpha: 1.0)
            ],
            [
                UIColor(red: 0.56, green: 0.18, blue: 0.91, alpha: 1.0),
                UIColor(red: 0.22, green: 0.07, blue: 0.37, alpha: 1.0)
            ]
        ]
        
        private var segmentSets: [SegmentLayerSet] = []
        private var score: Int = 0
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setup()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
        }
        
        private func setup() {
            backgroundColor = .clear
            isUserInteractionEnabled = false
            
            scoreLabel.translatesAutoresizingMaskIntoConstraints = false
            scoreLabel.textColor = .white
            scoreLabel.textAlignment = .center
            
            addSubview(scoreLabel)
            
            NSLayoutConstraint.activate([
                scoreLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                scoreLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
            
            for _ in 0..<3 {
                let segmentSet = SegmentLayerSet()
                
                segmentSet.trackLayer.fillColor = UIColor.clear.cgColor
                segmentSet.trackLayer.strokeColor = UIColor(white: 1.0, alpha: 0.08).cgColor
                segmentSet.trackLayer.lineCap = .butt
                
                segmentSet.progressLayer.fillColor = UIColor.clear.cgColor
                segmentSet.progressLayer.lineCap = .butt
                segmentSet.progressLayer.strokeStart = 0
                
                segmentSet.gradientLayer.mask = segmentSet.progressLayer
                segmentSet.gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
                segmentSet.gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
                
                layer.addSublayer(segmentSet.trackLayer)
                layer.addSublayer(segmentSet.gradientLayer)
                segmentSets.append(segmentSet)
            }
        }
        
        func configure(score: Int, centerFontSize: CGFloat) {
            self.score = max(0, min(score, 100))
            scoreLabel.text = "\(self.score)"
            scoreLabel.font = .systemFont(ofSize: centerFontSize, weight: .bold)
            setNeedsLayout()
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            layoutSegments()
        }
        
        private func layoutSegments() {
            guard bounds.width > 0, bounds.height > 0 else { return }
            
            let size = min(bounds.width, bounds.height)
            let lineWidth = max(18, size * 0.14)
            let radius = (size - lineWidth) / 2
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let segmentArc = CGFloat.pi * 0.60
            let gap = CGFloat.pi * 0.065
            let startAngles = [
                CGFloat.pi * 0.96,
                -CGFloat.pi / 2,
                CGFloat.pi * 0.27
            ]
            let progresses = segmentProgresses(for: score)
            
            for (index, segmentSet) in segmentSets.enumerated() {
                let startAngle = startAngles[index]
                let endAngle = startAngle + segmentArc
                
                let path = UIBezierPath(
                    arcCenter: center,
                    radius: radius,
                    startAngle: startAngle + gap,
                    endAngle: endAngle - gap,
                    clockwise: true
                )
                
                segmentSet.trackLayer.frame = bounds
                segmentSet.trackLayer.path = path.cgPath
                segmentSet.trackLayer.lineWidth = lineWidth
                
                segmentSet.progressLayer.frame = bounds
                segmentSet.progressLayer.path = path.cgPath
                segmentSet.progressLayer.lineWidth = lineWidth
                segmentSet.progressLayer.strokeEnd = progresses[index]
                
                segmentSet.gradientLayer.frame = bounds
                segmentSet.gradientLayer.colors = segmentColors[index].map(\.cgColor)
                segmentSet.progressLayer.shadowColor = segmentColors[index].first?.cgColor
                segmentSet.progressLayer.shadowOpacity = 0.28
                segmentSet.progressLayer.shadowRadius = 10
                segmentSet.progressLayer.shadowOffset = .zero
            }
        }
        
        private func segmentProgresses(for score: Int) -> [CGFloat] {
            let normalized = CGFloat(score) / 100.0
            
            return [
                max(0.18, min(1.0, normalized * 1.10)),
                max(0.16, min(1.0, normalized * 0.88 + 0.12)),
                max(0.14, min(1.0, normalized * 0.95))
            ]
        }
    }
