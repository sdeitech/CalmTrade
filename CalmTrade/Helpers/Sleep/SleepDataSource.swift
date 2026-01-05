//
//  SleepDataSource.swift
//  CalmTrade
//
//  Created by Anas Parekh on 17/11/25.
//


import Foundation

public enum SleepDataSource: Int, Codable {
    case ct360       = 0
    case appleHealth = 1

    public var displayName: String {
        switch self {
        case .ct360:       return "Polar 360"
        case .appleHealth: return "Apple Health"
        }
    }

    public var rawValueInt: Int { rawValue }

    init(rawValueInt: Int) {
        self = SleepDataSource(rawValue: rawValueInt) ?? .appleHealth
    }
}

