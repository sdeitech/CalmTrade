//
//  ProfitFactorViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 08/12/25.
//


// ProfitFactorViewModel.swift
import Foundation
import UIKit
import Combine

final class ProfitFactorViewModel {

    private let api = APIService()
    private(set) var response: ProfitFactorResponse?

    let reload = PassthroughSubject<Void, Never>()

    func fetchProfitFactor(filter: String) {
        let path = "analytics/profit-factor?filter=\(filter)"
        api.startService(
            with: .GET,
            path: path,
            parameters: nil,
            files: nil,
            modelType: ProfitFactorResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .Success(let res):
                    self?.response = res
                    self?.reload.send(())
                case .Error(let msg):
                    print("❌ Profit Factor API Error:", msg)
                }
            }
        }
    }

    // MARK: - Raw numeric values for gauge
    var wins: Double {
        response?.totalWinsValue ?? 0
    }

    var losses: Double {
        abs(response?.totalLossesValue ?? 0)
    }

    // MARK: - Text for UILabels
    var winsValueText: String {
        String(format: "%.2f", wins)
    }

    var lossesValueText: String {
        String(format: "%.2f", -losses) // UI shows negative sign
    }

    // MARK: - Progress bar percent (backend-driven)
    var winProgress: Float {
        Float((response?.winsPercent ?? 0) / 100.0)
    }

    var lossProgress: Float {
        Float((response?.lossesPercent ?? 0) / 100.0)
    }

    // MARK: - Gauge
    var gaugePercent: Double {
        response?.gauge?.percent ?? 0
    }
}



