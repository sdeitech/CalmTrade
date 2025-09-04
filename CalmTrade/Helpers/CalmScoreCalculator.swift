//
//  CalmScoreCalculator.swift
//  CalmTrade
//
//  Created by Anas Parekh on 01/09/25.
//


import Foundation

// MARK: - Input/Output Models

/// A standardized structure to pass all necessary biometric data into the calculator.
struct CalmScoreBiometricInputs {
    let heartRate: Double?
    let hrvInRmssd: Double?
    let restingHeartRate: Double?
    let sleepDurationInHours: Double?
}

/// **FIX**: A public structure for the emotional input to the Edge score.
/// Defining it here makes it accessible to the DeviceManager and ViewModels.
struct EmotionInputs {
    let valence: Double // -1 (negative) to +1 (positive)
    let arousal: Double // 0 (calm) to 1 (excited)
}

/// The final output, matching the structure from your schema.
struct CalmScoreSession {
    let version: String = "1.0.0"
    let timestampUtc: String = ISO8601DateFormatter().string(from: Date())
    let phase: Phase
    let readiness: Double
    let edge: Double
    let calmScore: Double
    let coveragePct: Double
    
    enum Phase: String {
        case pre, during, post
    }
}

/// The main calculation engine for the CalmScore.
class CalmScoreCalculator {
    
    // Weights for the Readiness formula from SPEC_CALMSCORE.md
    private let weights: [String: Double] = [
        "zHRV": 0.8, "zHR_star": 0.5, "zRHR_star": 0.3, "zSleep": 0.4, "zHRVTrend": 0.2
    ]
    
    /// The primary method to calculate the CalmScore.
    func calculate(from bioInputs: CalmScoreBiometricInputs, emotionInputs: EmotionInputs?, phase: CalmScoreSession.Phase) -> CalmScoreSession {
        
        // --- 1. Personal Normalization (z-scoring) ---
        let zHRV = normalize(value: bioInputs.hrvInRmssd, mean: 45.0, stddev: 12.0)
        let zHR = normalize(value: bioInputs.heartRate, mean: 70.0, stddev: 15.0)
        let zRHR = normalize(value: bioInputs.restingHeartRate, mean: 60.0, stddev: 8.0)
        let zSleep = normalize(value: bioInputs.sleepDurationInHours, mean: 7.5, stddev: 1.0)
        
        // --- 2. Transforms ---
        let zHR_star = -zHR
        let zRHR_star = -zRHR
        
        // --- 3. Calculate Readiness Score ---
        let weightedSum = (zHRV * weights["zHRV"]!) +
                          (zHR_star * weights["zHR_star"]!) +
                          (zRHR_star * weights["zRHR_star"]!) +
                          (zSleep * weights["zSleep"]!)
        
        let readiness = 100 * sigmoid(weightedSum)
        
        // --- 4. Calculate Edge Score ---
        var edge = 50.0 // Default Edge score
        if let emotions = emotionInputs {
            let emotionComponent = emotions.valence - emotions.arousal
            edge = 100 * sigmoid(emotionComponent)
        }
        
        // --- 5. Phase-Aware Blending ---
        let alpha = alpha(for: phase)
        let rawCalmScore = (alpha * readiness) + ((1 - alpha) * edge)
        let calmScore = max(0, min(100, rawCalmScore))
        
        // --- 6. Assemble Final Output ---
        return CalmScoreSession(phase: phase, readiness: readiness, edge: edge, calmScore: calmScore, coveragePct: 1.0)
    }
    
    // MARK: - Helper Functions
    private func normalize(value: Double?, mean: Double, stddev: Double) -> Double {
        guard let value = value, stddev > 0 else { return 0 }
        return (value - mean) / stddev
    }
    
    private func sigmoid(_ x: Double) -> Double {
        return 1 / (1 + exp(-x))
    }
    
    private func alpha(for phase: CalmScoreSession.Phase) -> Double {
        switch phase {
        case .pre: return 0.7
        case .during: return 0.5
        case .post: return 0.6
        }
    }
}
