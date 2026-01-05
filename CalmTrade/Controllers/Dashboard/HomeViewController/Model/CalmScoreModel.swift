//
//  CalmScoreSession.swift
//  CalmTrade
//
//  Created by Anas Parekh on 01/09/25.
//


import Foundation
import UIKit

// MARK: - Final Output Structure (matches calm_score.schema.json)

//struct CalmScoreSession: Codable {
//    let version: String
//    let sessionId: String?
//    let timestampUtc: String
//    let phase: Phase
//    let readiness: Double
//    let edge: Double
//    let calmScore: Double
//    let coveragePct: Double
//    let inputs: CalmScoreInputs
//    
//    enum Phase: String, Codable {
//        case pre, during, post
//    }
//}

// MARK: - Input Structures

struct CalmScoreInputs: Codable {
    let physio: PhysioInputs
    // We will add emotion and context later as per the spec.
}

/// Holds the raw, personalized z-scored physiological inputs.
struct PhysioInputs: Codable {
    let zHRV: Double?
    let zHR_star: Double?
    let zRHR_star: Double?
    let zSleep: Double?
    let zHRVTrend: Double?
}
//
//public enum DeviceSource: String {
//    case appleHK = "Apple HK"
//    case h10 = "H10"
//    case calm360 = "Calm360"
//    public var displayName: String { rawValue }
//}
//public struct TrendData: Equatable {
//    public var hrvMs: Double
//    public var hrvIsUp: Bool
//    public var hrBpm: Double
//    public var hrIsDown: Bool
//    public var sleepHours: Double
//    public var sleepIsUp: Bool
//    public init(hrvMs: Double, hrvIsUp: Bool, hrBpm: Double, hrIsDown: Bool, sleepHours: Double, sleepIsUp: Bool) {
//        self.hrvMs = hrvMs
//        self.hrvIsUp = hrvIsUp
//        self.hrBpm = hrBpm
//        self.hrIsDown = hrIsDown
//        self.sleepHours = sleepHours
//        self.sleepIsUp = sleepIsUp
//    }
//}
//public struct CalmScoreTileProps: Equatable {
//    public var score: Double   // 0...100
//    public var lastUpdate: Date
//    public var deviceSource: DeviceSource
//    public var isStreaming: Bool
//    public var trend: TrendData
//    public init(score: Double, lastUpdate: Date, deviceSource: DeviceSource, isStreaming: Bool, trend: TrendData) {
//        self.score = score
//        self.lastUpdate = lastUpdate
//        self.deviceSource = deviceSource
//        self.isStreaming = isStreaming
//        self.trend = trend
//    }
//}
//// MARK: - Colors
//extension UIColor {
//    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
//        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
//        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
//        let b = CGFloat(hex & 0xFF) / 255.0
//        self.init(red: r, green: g, blue: b, alpha: alpha)
//    }
//    static let neonMint = UIColor(hex: 0x00FFC3)
//    static let stressRed = UIColor(hex: 0xFF4D3D)
//    static let calmGreen = UIColor(hex: 0x00C96B)
//    static let gaugeYellow = UIColor(hex: 0xE2C74E)
//    static let bgBlack = UIColor(hex: 0x0F1115)
//    static let greyText = UIColor.white.withAlphaComponent(0.85)
//}
//
