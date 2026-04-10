//
//  TwoFAEnableResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 05/01/26.
//

import Foundation

struct TwoFAEnableResponse: Decodable {
    let success: Bool
    let message: String
    let qrCodeDataURL: String
    let manualEntryKey: String
}

struct GenericResponse: Decodable {
    let success: Bool
    let message: String
}
