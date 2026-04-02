//
//  SleepScoreDayModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/03/26.
//


import UIKit

struct SleepScoreDayModel {
    let date: Date
    let score: Int

    let sleepTimeMinutes: Int

    let amountScore: Int
    let solidityScore: Int
    let regenerationScore: Int

    let interruptionsScore: Int
    let continuityScore: Int
    let sleepEfficiencyScore: Int

    let remScore: Int
    let deepScore: Int
    let coreScore: Int

    // normalized 0...1 for bars/charts
    let amount: CGFloat
    let solidity: CGFloat
    let regeneration: CGFloat
    let rem: CGFloat
    let deep: CGFloat
    let core: CGFloat
}
