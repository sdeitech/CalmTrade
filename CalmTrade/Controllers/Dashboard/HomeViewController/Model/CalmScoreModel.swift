//
//  CalmScoreSession.swift
//  CalmTrade
//
//  Created by Anas Parekh on 01/09/25.
//


import Foundation

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
