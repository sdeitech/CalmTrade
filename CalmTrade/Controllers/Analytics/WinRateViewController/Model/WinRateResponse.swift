//
//  WinRateResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 27/11/25.
//


import Foundation

struct WinRateResponse: Decodable {
    let status: Int?
    let success: Bool?
    let winRate: Int?
    let wins: Int?
    let losses: Int?
    let changeFromLastPeriod: Int?
    let avgCalmScore: Int?
}
