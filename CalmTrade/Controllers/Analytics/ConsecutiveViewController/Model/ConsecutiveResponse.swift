//
//  ConsecutiveResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 01/12/25.
//


// ConsecutiveResponse.swift
import Foundation

struct ConsecutiveResponse: Decodable {
    let status: Int?
    let success: Bool?
    let consecutiveWins: Int?
    let consecutiveLosses: Int?
    let insight: String?
}
