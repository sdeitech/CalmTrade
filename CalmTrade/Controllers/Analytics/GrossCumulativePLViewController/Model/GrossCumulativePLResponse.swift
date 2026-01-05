//
//  GrossCumulativePLResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 09/12/25.
//


import Foundation

struct GrossCumulativePLResponse: Decodable {
    let status: Int?
    let success: Bool?
    let range: String?
    let startDate: String?
    let endDate: String?
    let data: [CumulativePLDTO]?
}

struct CumulativePLDTO: Decodable {
    let date: String
    let cumulativePnl: Double
}

struct CumulativePLPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
