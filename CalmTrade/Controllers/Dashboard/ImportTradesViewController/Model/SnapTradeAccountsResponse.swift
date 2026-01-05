//
//  SnapTradeAccountsResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 15/12/25.
//


struct SnapTradeAccountsResponse: Decodable {
    let status: Int?
    let success: Bool?
    let message: String?
    let data: [SnapTradeAccount]?
}

struct SnapTradeAccount: Decodable {
    let localAccountId: String
    let accountName: String
    let brokerName: String
    let accountNumber: String
    let syncStatus: String
    let lastSyncedAt: String?
    let connectedSnapTradeAccounts: [SnapTradeConnectedAccount]
}

struct SnapTradeConnectedAccount: Decodable {
    let id: String
    let name: String
    let type: String
    let balance: SnapBalanceWrapper
}

struct SnapBalanceWrapper: Decodable {
    let total: SnapBalance
}

struct SnapBalance: Decodable {
    let amount: Double
    let currency: String
}
