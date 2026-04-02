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
    
    private static let sleepScoreRingViewTag = 98_421
    
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
        }
    }
    
    func numberOfItems() -> Int {
        switch mode {
        case .daily: return dailyModel == nil ? 0 : 1
        case .weekly: return weeklyModels.count
        }
    }
    
    func model(at index: Int) -> SleepScoreDayModel? {
        switch mode {
        case .daily:
            return dailyModel
        case .weekly:
            guard weeklyModels.indices.contains(index) else { return nil }
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
    }
    
    @discardableResult
    static func makeSleepScoreRing(
        in containerView: UIView,
        score: Int,
        segmentProgresses: [CGFloat],
        centerFontSize: CGFloat
    ) -> UIView {
        if let ringView = containerView.viewWithTag(sleepScoreRingViewTag) as? SleepScoreRingContainerView {
            ringView.configure(
                score: score,
                segmentProgresses: segmentProgresses,
                centerFontSize: centerFontSize
            )
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
        
        ringView.configure(
            score: score,
            segmentProgresses: segmentProgresses,
            centerFontSize: centerFontSize
        )
        return ringView
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
                UIColor(red: 0.06, green: 0.18, blue: 0.20, alpha: 1.0)
            ],
            [
                UIColor(red: 0.99, green: 0.62, blue: 0.24, alpha: 1.0),
                UIColor(red: 0.26, green: 0.14, blue: 0.05, alpha: 1.0)
            ],
            [
                UIColor(red: 0.56, green: 0.18, blue: 0.91, alpha: 1.0),
                UIColor(red: 0.10, green: 0.03, blue: 0.18, alpha: 1.0)
            ]
        ]
        
        private var segmentSets: [SegmentLayerSet] = []
        private var score: Int = 0
        private var segmentProgressValues: [CGFloat] = [0.18, 0.16, 0.14]
        
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
            scoreLabel.layer.shadowColor = UIColor.black.cgColor
            scoreLabel.layer.shadowOpacity = 0.22
            scoreLabel.layer.shadowRadius = 6
            scoreLabel.layer.shadowOffset = .zero
            
            addSubview(scoreLabel)
            
            NSLayoutConstraint.activate([
                scoreLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                scoreLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
            
            for _ in 0..<3 {
                let segmentSet = SegmentLayerSet()
                
                segmentSet.trackLayer.fillColor = UIColor.clear.cgColor
                segmentSet.trackLayer.strokeColor = UIColor(white: 1.0, alpha: 0.06).cgColor
                segmentSet.trackLayer.lineCap = .round
                
                segmentSet.progressLayer.fillColor = UIColor.clear.cgColor
                segmentSet.progressLayer.lineCap = .round
                segmentSet.progressLayer.strokeStart = 0
                
                segmentSet.gradientLayer.mask = segmentSet.progressLayer
                segmentSet.gradientLayer.locations = [0.0, 0.55, 1.0]
                
                layer.addSublayer(segmentSet.trackLayer)
                layer.addSublayer(segmentSet.gradientLayer)
                segmentSets.append(segmentSet)
            }
        }
        
        func configure(score: Int, segmentProgresses: [CGFloat], centerFontSize: CGFloat) {
            self.score = max(0, min(score, 100))
            self.segmentProgressValues = normalizedSegmentProgresses(from: segmentProgresses)
            scoreLabel.text = "\(self.score)"
            scoreLabel.font = .systemFont(ofSize: centerFontSize * 0.88, weight: .heavy)
            setNeedsLayout()
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            layoutSegments()
        }
        
        private func layoutSegments() {
            guard bounds.width > 0, bounds.height > 0 else { return }
            
            let size = min(bounds.width, bounds.height)
            let lineWidth = max(17, size * 0.135)
            let radius = (size - lineWidth) / 2.08
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let segmentArc = CGFloat.pi * 0.60
            let gap = CGFloat.pi * 0.032
            let startAngles = [
                CGFloat.pi * 0.88,
                CGFloat.pi * 1.56,
                CGFloat.pi * 0.22
            ]
            let progresses = segmentProgressValues
            
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
                segmentSet.progressLayer.strokeColor = UIColor.white.cgColor
                
                segmentSet.gradientLayer.frame = bounds
                segmentSet.gradientLayer.colors = gradientColors(for: index)
                applyGradientDirection(for: index, to: segmentSet.gradientLayer)
                segmentSet.progressLayer.shadowColor = segmentColors[index].first?.cgColor
                segmentSet.progressLayer.shadowOpacity = 0.22
                segmentSet.progressLayer.shadowRadius = 8
                segmentSet.progressLayer.shadowOffset = .zero
            }
        }

        private func gradientColors(for index: Int) -> [CGColor] {
            let bright = segmentColors[index].first ?? .white
            let deep = segmentColors[index].last ?? bright.withAlphaComponent(0.25)
            
            return [
                deep.withAlphaComponent(0.10).cgColor,
                deep.withAlphaComponent(1.0).cgColor,
                bright.cgColor
            ]
        }
        
        private func applyGradientDirection(for index: Int, to layer: CAGradientLayer) {
            switch index {
            case 0:
                layer.startPoint = CGPoint(x: 0.18, y: 0.88)
                layer.endPoint = CGPoint(x: 0.78, y: 0.16)
            case 1:
                layer.startPoint = CGPoint(x: 0.14, y: 0.18)
                layer.endPoint = CGPoint(x: 0.88, y: 0.70)
            default:
                layer.startPoint = CGPoint(x: 0.26, y: 0.10)
                layer.endPoint = CGPoint(x: 0.84, y: 0.88)
            }
        }
        
        private func segmentProgresses(for score: Int) -> [CGFloat] {
            let normalized = CGFloat(score) / 100.0
            
            return [
                max(0.0, min(1.0, normalized * 1.10)),
                max(0.0, min(1.0, normalized * 0.88 + 0.12)),
                max(0.0, min(1.0, normalized * 0.95))
            ]
        }
        
        private func normalizedSegmentProgresses(from values: [CGFloat]) -> [CGFloat] {
            let fallback = segmentProgresses(for: score)
            let clamped = values.prefix(3).map { max(0.0, min(1.0, $0)) }
            
            guard clamped.count == 3 else { return fallback }
            return clamped
        }
    }
}

 
