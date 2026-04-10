//
//  GenericResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/01/26.
//


struct VerifyChangeEmailResponse: Decodable {
    let status: Int
    let success: Bool
    let message: String?
    let newEmail: String
}
