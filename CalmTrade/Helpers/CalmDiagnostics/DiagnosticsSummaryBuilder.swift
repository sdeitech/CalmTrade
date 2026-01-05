//
//  DiagnosticsSummaryBuilder.swift
//  CalmTrade
//
//  Created by Anas Parekh on 20/11/25.
//


enum DiagnosticsSummaryBuilder {
    static func build(from debug: CalmScoreDebugResult) -> String {
        var lines: [String] = []

        if let hrv = debug.zHRV {
            if hrv > 0 { lines.append("HRV increased score by \(debug.contribHRV.rounded()).") }
            else       { lines.append("Low HRV reduced score by \((-debug.contribHRV).rounded()).") }
        }

        if let hr = debug.zHR {
            if hr > 0 { lines.append("Lower HR improved score.") }
            else      { lines.append("Elevated HR reduced score.") }
        }

        if let rhr = debug.zRHR {
            if rhr > 0 { lines.append("Resting HR trending better.") }
            else       { lines.append("High resting HR reduced readiness.") }
        }

        if let slp = debug.zSlp {
            if slp > 0 { lines.append("Good sleep improved score.") }
            else       { lines.append("Low sleep weakened recovery.") }
        }

        return lines.joined(separator: " ")
    }
}
