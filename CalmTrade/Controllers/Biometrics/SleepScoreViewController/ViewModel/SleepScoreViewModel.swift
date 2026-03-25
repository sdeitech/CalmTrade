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
    }
}
