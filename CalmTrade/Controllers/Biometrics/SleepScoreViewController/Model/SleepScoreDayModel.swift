//
//  SleepScoreDayModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/03/26.
//


import UIKit

struct SleepScoreDayModel {
    let date: Date
    let score: Int          // 0...100
    
    // normalized 0...1
    let amount: CGFloat
    let solidity: CGFloat
    let regeneration: CGFloat
    let rem: CGFloat
    let deep: CGFloat
}
