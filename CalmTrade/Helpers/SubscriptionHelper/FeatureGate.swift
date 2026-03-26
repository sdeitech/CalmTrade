//
//  FeatureGate.swift
//  CalmTrade
//
//  Created by Anas Parekh on 10/02/26.
//

import Foundation
import SwiftUICore
import UIKit
import SwiftUI

enum FeatureAccess {
    case allowed
    case locked(plan: SubscriptionPlanCase)
}

enum SubscriptionPlanCase {
    case free
    case pro
    case elite

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .elite: return "Elite"
        }
    }

    var badgeColor: Color {
        switch self {
        case .free: return .gray
        case .pro: return .blue
        case .elite: return .yellow
        }
    }

    var ctaGradient: LinearGradient {
        switch self {
        case .pro:
            return LinearGradient(
                colors: [Color.blue, Color.cyan],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .elite:
            return LinearGradient(
                colors: [Color.yellow, Color.orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .free:
            return LinearGradient(
                colors: [Color.gray],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

final class FeatureGate {

    static let shared = FeatureGate()

    private init() {}

    func access(for feature: String) -> FeatureAccess {
//        guard let user = SessionManager.shared.current else {
//            return .locked(plan: .free)
//        }

//        if user.hasFeature(feature) {
            return .allowed
//        }

//        return .locked(plan: requiredPlan(for: feature))
    }

    private func requiredPlan(for feature: String) -> SubscriptionPlanCase {
        switch feature {

        // PRO
        case FeatureKey.calmScoreGauge,
             FeatureKey.tradeAnalyticsStats,
             FeatureKey.journalUnlocked,
             FeatureKey.customEmotions:
            return .pro

        // ELITE
        case FeatureKey.brokerSync,
             FeatureKey.realtime360Sync,
             FeatureKey.chartsForBiometric,
             FeatureKey.multipleAccountHandling:
            return .elite

        default:
            return .free
        }
    }
    
    func presentUpgradeSheet(for feature: String,from sourceView: UIViewController) {
        let view = UniversalUpgradeSheet(
            featureKey: feature,
            onSubscribe: {
                sourceView.dismiss(animated: true)
                sourceView.navigationController?.pushViewController(UIStoryboard(name: Constants.Storyboard.Profile, bundle: nil).instantiateViewController(withIdentifier: "SubscriptionViewController") as! SubscriptionViewController)
            },
            onLater: {
                sourceView.dismiss(animated: true)
            }
        )

        let vc = UIHostingController(rootView: view)
        vc.modalPresentationStyle = .pageSheet
//        vc.view.backgroundColor = .clear

        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = 24
        }

        sourceView.present(vc, animated: true)
    }

}
