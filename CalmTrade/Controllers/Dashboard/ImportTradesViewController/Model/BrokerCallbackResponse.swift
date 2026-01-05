//
//  BrokerCallbackResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 13/12/25.
//

import Foundation

struct BrokerCallbackResponse: Decodable {
    let success: Bool?
    let message: String?
    let data: BrokerCallbackData?
}

struct BrokerCallbackData: Decodable {
    let accounts: [BrokerAccount]?
}

struct BrokerAccount: Decodable {
    let accountId: String
    let connectionId: String?
    let brokerName: String?
    let accountNumber: String?
}

struct BrokerSyncResponse: Decodable {
    let success: Bool?
    let message: String?
}

