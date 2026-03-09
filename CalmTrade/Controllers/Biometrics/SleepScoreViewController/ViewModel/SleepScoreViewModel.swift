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
        case .daily: return 2
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
}
