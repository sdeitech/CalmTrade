//
//  CheckoutResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 10/12/25.
//


struct CheckoutResponse: Decodable {
    let status: Int?
    let success: Bool?
    let message: String?
    let data: CheckoutData?
}

struct CheckoutData: Decodable {
    let checkoutUrl: String
    let sessionId: String
    let orderId: String
    let oID: String
}
