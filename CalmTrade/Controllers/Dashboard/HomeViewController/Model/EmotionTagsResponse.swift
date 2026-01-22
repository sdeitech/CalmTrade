//
//  EmotionTagsResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 19/01/26.
//


import Foundation

struct EmotionTagsResponse: Decodable {
    let status: Int
    let success: Bool
    let categories: [EmotionCategoryDTO]
}

struct EmotionCategoryDTO: Decodable {
    let id: String
    let name: String
    let colorCode: String
    let tags: [EmotionTagDTO]
}

struct EmotionTagDTO: Decodable {
    let id: String?
    let name: String
    let valence: Double
    let arousal: Double
}
