//
//  NightlyRechargeViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 09/03/26.
//


import Foundation
import CoreGraphics
import PolarBleSdk

struct NightlyRechargeUIModel {

    let status: String
    let statusLevel: CGFloat
    let statusUsesFallback: Bool

    let ansTitle: String
    let ansDeviationText: String
    let ansRateText: String
    let ansOffsetRatio: CGFloat

    let sleepTitle: String
    let sleepScoreText: String
    let usualSleepText: String
    let sleepOffsetRatio: CGFloat
}

final class NightlyRechargeViewModel {

    var onLoadingChanged: ((Bool) -> Void)?
    var onDataLoaded: ((NightlyRechargeUIModel) -> Void)?
    var onError: ((String) -> Void)?

    func loadData() {
        onLoadingChanged?(true)

        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

        NSLog(
            "[PM][NR][UI] requesting nightly recharge window %@ -> %@",
            formatter.string(from: start),
            formatter.string(from: end)
        )

        PolarManager.shared.fetchNightlyRecharge(from: start, to: end) { [weak self] result in
            guard let self else { return }

            self.onLoadingChanged?(false)

            switch result {
            case .success(let snapshot):
                guard let latest = self.latestEntry(from: snapshot.entries) else {
                    self.onError?("No nightly recharge data available yet.")
                    return
                }

                let latestDate = self.sortDate(for: latest)
                NSLog(
                    "[PM][NR][UI] rendering latest nightly recharge for %@",
                    formatter.string(from: latestDate)
                )

                self.onDataLoaded?(self.makeUIModel(from: latest))
            case .failure(let error):
                self.onError?(error.localizedDescription)
            }
        }
    }

    private func latestEntry(from entries: [PolarNightlyRechargeData]) -> PolarNightlyRechargeData? {
        entries.max { lhs, rhs in
            let lhsDate = sortDate(for: lhs)
            let rhsDate = sortDate(for: rhs)
            return lhsDate < rhsDate
        }
    }

    private func sortDate(for entry: PolarNightlyRechargeData) -> Date {
        if let resultDate = Calendar.current.date(from: entry.sleepResultDate ?? DateComponents()) {
            return resultDate
        }
        return entry.createdTimestamp
    }

    private func makeUIModel(from entry: PolarNightlyRechargeData) -> NightlyRechargeUIModel {
        let validAnsStatus = sanitizedAnsStatus(entry.ansStatus)
        let validAnsRate = sanitizedRate(entry.ansRate)
        let validSleepRate = sanitizedRate(entry.scoreRateObsolete)
        let validRecoveryIndicator = sanitizedRecoveryIndicator(entry.recoveryIndicator)
        let validRecoverySubLevel = sanitizedRecoverySubLevel(entry.recoveryIndicatorSubLevel)
        let rawRMSSD = sanitizedPositiveMetric(entry.meanNightlyRecoveryRMSSD)
        let rawRRI = sanitizedPositiveMetric(entry.meanNightlyRecoveryRRI)
        let rawRespiration = sanitizedPositiveMetric(entry.meanNightlyRecoveryRespirationInterval)

        if validRecoveryIndicator == nil,
           validAnsStatus == nil,
           validAnsRate == nil,
           validSleepRate == nil,
           rawRMSSD != nil || rawRRI != nil || rawRespiration != nil {
            return makeRawFallbackUIModel(
                rmssd: rawRMSSD,
                rri: rawRRI,
                respiration: rawRespiration
            )
        }

        let ansDeviationText = validAnsStatus.map { String(format: "%+.1f", $0) } ?? "--"
        let ansTitle = validAnsStatus.map {
            comparisonTitle(for: $0, strongThreshold: 7.5, mildThreshold: 2.5)
        } ?? "Unavailable"
        let sleepTitle = validSleepRate.map(sleepChargeTitle(for:)) ?? "Unavailable"
        let sleepScoreText = validSleepRate.map { "\($0)/5" } ?? "--"
        let usualSleepText = validSleepRate.map { "Score \($0)/5" } ?? "Score --"
        let ansRateText = validAnsRate.map { String($0) } ?? "--"

        return NightlyRechargeUIModel(
            status: validRecoveryIndicator.map(statusTitle(for:)) ?? "Unavailable",
            statusLevel: normalizedRecoveryLevel(
                indicator: validRecoveryIndicator,
                subLevel: validRecoverySubLevel
            ),
            statusUsesFallback: false,
            ansTitle: ansTitle,
            ansDeviationText: ansDeviationText,
            ansRateText: ansRateText,
            ansOffsetRatio: validAnsStatus.map { clamp($0 / 15.7068) } ?? 0,
            sleepTitle: sleepTitle,
            sleepScoreText: sleepScoreText,
            usualSleepText: usualSleepText,
            sleepOffsetRatio: validSleepRate.map(sleepOffsetRatio(rate:)) ?? 0
        )
    }

    private func makeRawFallbackUIModel(
        rmssd: Int?,
        rri: Int?,
        respiration: Int?
    ) -> NightlyRechargeUIModel {
        let ansPrimary = rmssd.map { "\($0) ms" } ?? "--"
        let ansSecondary = rri.map { "\($0) ms" } ?? "--"
        let respirationText = respiration.map { "\($0) ms" } ?? "--"
        let rriDetail = rri.map { "RRI \($0) ms" } ?? "RRI --"

        return NightlyRechargeUIModel(
            status: "Raw metrics only",
            statusLevel: 0.35,
            statusUsesFallback: true,
            ansTitle: "RMSSD (raw)",
            ansDeviationText: ansPrimary,
            ansRateText: ansSecondary,
            ansOffsetRatio: 0,
            sleepTitle: "Respiration (raw)",
            sleepScoreText: respirationText,
            usualSleepText: rriDetail,
            sleepOffsetRatio: 0
        )
    }

    private func statusTitle(for indicator: Int) -> String {
        switch indicator {
        case 6:
            return "Very Good"
        case 5:
            return "Good"
        case 4:
            return "Solid"
        case 3:
            return "Okay"
        case 2:
            return "Compromised"
        case 1:
            return "Poor"
        default:
            return "Unavailable"
        }
    }

    private func comparisonTitle(for value: Double, strongThreshold: Double, mildThreshold: Double) -> String {
        switch value {
        case let x where x >= strongThreshold:
            return "Much above usual"
        case let x where x >= mildThreshold:
            return "Above usual"
        case let x where x <= -strongThreshold:
            return "Much below usual"
        case let x where x <= -mildThreshold:
            return "Below usual"
        default:
            return "Usual"
        }
    }

    private func sleepChargeTitle(for rate: Int) -> String {
        switch rate {
        case 5:
            return "Much above usual"
        case 4:
            return "Above usual"
        case 3:
            return "Usual"
        case 2:
            return "Below usual"
        case 1:
            return "Much below usual"
        default:
            return "Unavailable"
        }
    }

    private func normalizedRecoveryLevel(indicator: Int?, subLevel: Int?) -> CGFloat {
        guard let indicator, (1...6).contains(indicator) else { return 0.2 }
        let base = CGFloat(indicator) / 6.0
        let refinement = CGFloat(max(0, min(100, subLevel ?? 0))) / 1000.0
        return min(1.0, max(0.2, base + refinement))
    }

    private func sleepOffsetRatio(rate: Int) -> CGFloat {
        guard (1...5).contains(rate) else { return 0 }
        let centered = CGFloat(rate - 3) / 2.0
        return clamp(centered)
    }

    private func clamp(_ value: Double) -> CGFloat {
        CGFloat(min(1.0, max(-1.0, value)))
    }

    private func sanitizedRate(_ value: Int?) -> Int? {
        guard let value, (1...5).contains(value) else { return nil }
        return value
    }

    private func sanitizedRecoveryIndicator(_ value: Int?) -> Int? {
        guard let value, (1...6).contains(value) else { return nil }
        return value
    }

    private func sanitizedRecoverySubLevel(_ value: Int?) -> Int? {
        guard let value, (0...100).contains(value) else { return nil }
        return value
    }

    private func sanitizedAnsStatus(_ value: Float?) -> Double? {
        guard let value else { return nil }
        let castValue = Double(value)
        guard (-15.7068...15.7068).contains(castValue) else { return nil }
        return castValue
    }

    private func sanitizedPositiveMetric(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }
}
