//
//  CalmScoreDebugResult.swift
//  CalmTrade
//
//  Created by Anas Parekh on 20/11/25.
//


public struct CalmScoreDebugResult {
    let zHRV: Double?
    let zHR: Double?
    let zRHR: Double?
    let zSlp: Double?
    let contribHRV: Double
    let contribHR: Double
    let contribRHR: Double
    let contribSlp: Double
    let finalScore: Double
}

extension CalmScoreCalculator {

    func debugMetrics(from inputs: CalmScoreBiometricInputs,
                      baselines bl: Baselines? = nil) -> CalmScoreDebugResult {

        let base = bl ?? Baselines(
            rmssd: defaultRmssd,
            sdnn:  defaultSdnn,
            hr:    defaultHR,
            rhr:   defaultRHR,
            sleep: defaultSleep
        )

        // MARK: - Z-SCORES

        // HRV (RMSSD + SDNN merged)
        let zRmssd = zLog(value: inputs.hrvInRmssd, baseline: base.rmssd ?? defaultRmssd)
        let zSdnn  = zLog(value: inputs.hrvInSdnn,  baseline: base.sdnn  ?? defaultSdnn)

        let zHRV: Double? = {
            if let zr = zRmssd, let zs = zSdnn {
                let combined = (Tunables.wRmssd * zr + Tunables.wSdnn * zs)
                             / (Tunables.wRmssd + Tunables.wSdnn)
                let penalty = Tunables.divergenceLambda * abs(zr - zs)
                return combined - penalty
            }
            return zRmssd ?? zSdnn
        }()

        let zHR  = zLinear(value: inputs.heartRate, baseline: base.hr ?? defaultHR)?.neg()
        let zRHR = zLinear(value: inputs.restingHeartRate, baseline: base.rhr ?? defaultRHR)?.neg()
        let zSlp = zLinear(value: inputs.sleepDurationInHours, baseline: base.sleep ?? defaultSleep)

        // MARK: - CONTRIBUTIONS (z * weight)

        let contribHRV  = (zHRV ?? 0) * Tunables.wHRV
        let contribHR   = (zHR  ?? 0) * Tunables.wHR
        let contribRHR  = (zRHR ?? 0) * Tunables.wRHR
        let contribSlp  = (zSlp ?? 0) * Tunables.wSleep

        // Weighted Z calculation using same formula
        var weightedZ = 0.0
        var weightSum = 0.0

        func add(_ z: Double?, _ w: Double) {
            if let z {
                weightedZ += z * w
                weightSum += w
            }
        }

        add(zHRV, Tunables.wHRV)
        add(zHR,  Tunables.wHR)
        add(zRHR, Tunables.wRHR)
        add(zSlp, Tunables.wSleep)

        let scoreZ = weightSum > 0 ? (weightedZ / weightSum) : 0.0

        // Final score (same sigmoid formula)
        let norm = sigmoid(Tunables.slope * scoreZ + Tunables.bias)
        let finalScore = clamp01(norm) * 100.0

        // MARK: - Return result
        return CalmScoreDebugResult(
            zHRV: zHRV,
            zHR: zHR,
            zRHR: zRHR,
            zSlp: zSlp,
            contribHRV: contribHRV,
            contribHR: contribHR,
            contribRHR: contribRHR,
            contribSlp: contribSlp,
            finalScore: finalScore
        )
    }
}

