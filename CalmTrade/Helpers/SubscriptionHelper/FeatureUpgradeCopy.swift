//
//  FeatureUpgradeCopy.swift
//  CalmTrade
//
//  Created by Anas Parekh on 10/02/26.
//

import Foundation

struct FeatureUpgradeInfo {
    let icon: String
    let title: String
    let message: String
}

enum FeatureUpgradeCopy {

    static func info(for feature: String) -> FeatureUpgradeInfo {
        switch feature {

        case FeatureKey.calmScoreGauge:
            return FeatureUpgradeInfo(
                icon: "waveform.path.ecg",
                title: "CalmScore Locked",
                message: "Understand how stress, HRV, and sleep impact your trading performance."
            )

        case FeatureKey.brokerSync:
            return FeatureUpgradeInfo(
                icon: "link",
                title: "Broker Sync Locked",
                message: "Automatically sync your trades and eliminate manual imports."
            )

        case FeatureKey.customEmotions:
            return FeatureUpgradeInfo(
                icon: "slider.horizontal.3",
                title: "Custom Emotions Locked",
                message: "Create and track emotions that matter to your trading psychology."
            )

        case FeatureKey.tradeAnalyticsStats:
            return FeatureUpgradeInfo(
                icon: "chart.bar.xaxis",
                title: "Advanced Analytics Locked",
                message: "Unlock deeper insights into your trading performance and patterns."
            )

        default:
            return FeatureUpgradeInfo(
                icon: "lock.fill",
                title: "Feature Locked",
                message: "Subscribe to unlock this feature."
            )
        }
    }
}
