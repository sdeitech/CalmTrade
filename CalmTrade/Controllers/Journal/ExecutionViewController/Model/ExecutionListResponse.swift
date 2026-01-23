//
//  ExecutionListResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 12/01/26.
//

import Foundation

struct ExecutionListResponse: Decodable {
    let status: Int?
    let success: Bool?
    let data: [ExecutionItem]?
}

struct ExecutionItem: Decodable, Hashable {
    let time: String
    let timestamp: String
    let symbol: String
    let side: String
    let size: Int?
    let pnl: Double?
}
