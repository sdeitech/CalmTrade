//
//  BrokerConnectResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 11/12/25.
//


struct BrokerConnectResponse: Decodable {
    let status: Int?
    let success: Bool?
    let message: String?
    let data: BrokerConnectData?
}

struct BrokerConnectData: Decodable {
    let redirectURI: String
    let sessionId: String
}
