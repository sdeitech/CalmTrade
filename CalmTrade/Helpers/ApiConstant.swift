//
//  ApiConstant.swift
//  iOSArchitecture_MVVM
//
//  Created by Surjeet Singh on 15/03/2019.
//  Copyright © 2019 Surjeet Singh. All rights reserved.
//

//  ApiConstant.swift  (REPLACE FILE)
//
//  Multi-environment config + legacy compatibility layer for existing code.

import Foundation

// MARK: - Environments
enum AppEnv: String {
    case local
    case staging
    case live
}

// Choose at build time via Schemes/xcconfig (see section 4)
enum BuildConfig {
    static let current: AppEnv = {
//        #if DEVELOPMENT
//        return .local
//        #elseif STAGING
        return .staging
//        #else
//        return .live
//        #endif
    }()

    static var baseURL: String {
        switch current {
        case .local:   return "https://pnh6dngr-8000.inc1.devtunnels.ms/"//"https://vdfqw6hb-8000.inc1.devtunnels.ms/"
        case .staging: return "http://44.211.113.36:8086/"
        case .live:    return "https://api.getcalmtrade.com/"
        }
    }

    static var websocketURL: URL {
        switch current {
        case .local:   return URL(string: "https://pnh6dngr-8000.inc1.devtunnels.ms/")!
        case .staging: return URL(string: "http://44.211.113.36:8086/")!
        case .live:    return URL(string: "https://api.getcalmtrade.com/")!
        }
    }
}

// MARK: - Endpoints (typed and discoverable)
enum Endpoints {
    enum Auth: String {
        case login = "user/login"
        case register = "user/register"
        case googleAuth = "user/googleAuth"
        case appleAuth = "user/appleAuth"
        case facebookAuth = "user/facebook"
        case verifyResetLink = "user/verifyResetLink"
        case verifyEmailOtp = "user/verify-email-otp"
        case resendVerification = "user/resend"
        case forgotPassword = "user/forgot-password"
        case verifyOTP = "user/verify-otp"
        case resetPassword = "user/reset-password"
        case getProfile = "user/getProfile"
    }
    
    enum Users: String {
        case me   = "/users/me"
        case list = "/users"
        case setBalance = "acc/accountBalance"
        case getBalance = "acc/account"
        case importTrades = "trades/import"
        case connectBroker = "broker/connect"
    }
}

// MARK: - Legacy keys (keep as-is for provided files)
enum Keys {
    static let email    = "email"
    static let password = "password"
    static let name     = "name"
    static let phone    = "phoneNumber"
}

// MARK: - Legacy compatibility (existing code references Config.BASE_URL / Config.login)
enum Config {
    static let BASE_URL: String = BuildConfig.baseURL
    static let login = String(Endpoints.Auth.login.rawValue.dropFirst()) // "registration_ctrl/login"
    // NOTE: new code should prefer `Endpoints.*` and not this shim.
}
