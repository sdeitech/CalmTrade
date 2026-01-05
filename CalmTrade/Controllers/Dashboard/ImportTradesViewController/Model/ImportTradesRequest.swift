//
//  ImportTradesModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/11/25.
//

import Foundation

struct ImportTradesRequest {
    let accountName: String
    let broker: String
    let timezone: String
    let fileData: Data
    let fileName: String
    let mimeType: String
}

struct ImportTradesResponse: Decodable {
    let success: Bool
    let message: String
}
