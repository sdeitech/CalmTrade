//
//  LocalTimeZoneModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 30/10/25.
//

import Foundation

struct LocalTimeZoneModel: Codable, Hashable {
    let tzid: String
    let friendlyName: String
    let offsetNow: String
    let isDstNow: Bool
    let labelNow: String

    enum CodingKeys: String, CodingKey {
        case tzid
        case friendlyName = "friendly_name"
        case offsetNow = "offset_now"
        case isDstNow = "is_dst_now"
        case labelNow = "label_now"
    }
}
