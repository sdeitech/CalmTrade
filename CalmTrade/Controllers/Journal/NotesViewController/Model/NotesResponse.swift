//
//  NotesResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 13/01/26.
//


import Foundation

struct NotesResponse: Decodable {
    let success: Bool
    let data: [Note]
    let pagination: Pagination
}


struct Note: Decodable {
    let id: String
    let noteType: String
    let content: String
    let timestamp: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case noteType
        case content
        case timestamp
        case createdAt
        case updatedAt
    }
}

struct Pagination: Decodable {
    let page: Int
    let limit: Int
    let total: Int
    let pages: Int
}
