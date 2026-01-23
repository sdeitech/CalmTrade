//
//  EmotionCategoryModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 21/01/26.
//

import Foundation

struct EmotionCategoryModel {
    let id: String
    let name: String
    let colorHex: String
    var tags: [EmotionTagModel]
}

struct EmotionTagModel {
    let id: String
    var name: String
}
