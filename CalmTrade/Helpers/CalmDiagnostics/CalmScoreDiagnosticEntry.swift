//
//  CalmScoreDiagnosticEntry.swift
//  CalmTrade
//
//  Created by Anas Parekh on 20/11/25.
//

import Foundation


struct CalmScoreDiagnosticEntry: Equatable {
    static func == (lhs: CalmScoreDiagnosticEntry, rhs: CalmScoreDiagnosticEntry) -> Bool {
        lhs.timestamp == rhs.timestamp &&
        lhs.finalScore == rhs.finalScore
    }
    
    let timestamp: Date
    
    // Raw inputs
    let inputs: CalmScoreBiometricInputs
    
    // Z-scores
    let zHRV: Double?
    let zHR: Double?
    let zRHR: Double?
    let zSleep: Double?
    
    // Weighted contributions
    let contribHRV: Double
    let contribHR: Double
    let contribRHR: Double
    let contribSleep: Double
    
    // Final score
    let finalScore: Double
    
    // Summary text
    let summary: String
}
