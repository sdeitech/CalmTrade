//
//  RegisterResponseModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 30/09/25.
//

import Foundation

/// Common response model for both Login and Register flows.
struct RegisterResponseModel: Codable {
    let success: Bool
    let message: String?
    let status: Int?
    let isVerified: Bool?   // Present in login response only
//    let user: User?         // Present in register response only
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case status
        case isVerified
//        case user
    }
    
    init(success: Bool,
         message: String? = nil,
         status: Int? = nil,
         isVerified: Bool? = nil) {
        self.success = success
        self.message = message
        self.status = status
        self.isVerified = isVerified
    }
}

/// One envelope for every Auth endpoint (email login, register, Google, Apple, Facebook).
struct AuthResponse: Decodable {
    let success: Bool
    let message: String?
    let status: Int?

    /// Present in email-login response (when account not verified yet)
    let isVerified: Bool?

    /// Present in social auth responses (and you can also return it for email if useful)
    let isFirstTimeUser: Bool?
    let newAccount: Bool?
    
    let accessToken: String?
}
