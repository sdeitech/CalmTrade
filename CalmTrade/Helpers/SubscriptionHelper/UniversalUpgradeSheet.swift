//
//  UniversalUpgradeSheet.swift
//  CalmTrade
//
//  Created by Anas Parekh on 10/02/26.
//

import SwiftUI

struct UniversalUpgradeSheet: View {

    let featureKey: String
    let onSubscribe: () -> Void
    let onLater: () -> Void

    private var info: FeatureUpgradeInfo {
        FeatureUpgradeCopy.info(for: featureKey)
    }

    var body: some View {
        Spacer()
        VStack(spacing: 20) {

            // Icon
            Image(systemName: info.icon)
                .font(.system(size: 36))
                .foregroundColor(.blue)

            // Title
            Text(info.title)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            // Message
            Text(info.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Subscribe CTA
            Button(action: onSubscribe) {
                Text("Subscribe")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }

            // Later
            Button("Later", action: onLater)
                .font(.footnote)
                .foregroundColor(.secondary)

        }
        .padding(24)
    }
}

#Preview("CalmScore Locked") {
    UniversalUpgradeSheet(
        featureKey: FeatureKey.calmScoreGauge,
        onSubscribe: {
            print("Subscribe tapped – CalmScore")
        },
        onLater: {
            print("Later tapped")
        }
    )
    .preferredColorScheme(.dark)
}
