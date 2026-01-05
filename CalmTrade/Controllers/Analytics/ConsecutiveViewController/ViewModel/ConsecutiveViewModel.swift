//
//  ConsecutiveViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 01/12/25.
//


import Foundation

final class ConsecutiveViewModel {

    // OUTPUTS (VC observes these)
    var winsText: ((String) -> Void)?
    var lossesText: ((String) -> Void)?
    var insightText: ((String) -> Void)?
    var showError: ((String) -> Void)?
    var setLoading: ((Bool) -> Void)?

    // MARK: - API call
    func fetchConsecutive(filter: String) {
        setLoading?(true)

        let path = "analytics/consecutive?filter=\(filter)"

        APIService().startService(
            with: .GET,
            path: path,
            parameters: nil,
            files: nil,
            modelType: ConsecutiveResponse.self
        ) { [weak self] result in
            guard let self else { return }

            self.setLoading?(false)

            switch result {
            case .Success(let response):
                guard let res = response else {
                    self.showError?("Invalid API response")
                    return
                }

                self.winsText?("\(res.consecutiveWins ?? 0)")
                self.lossesText?("\(res.consecutiveLosses ?? 0)")
                self.insightText?(res.insight ?? "")

            case .Error(let message):
                self.showError?(message)
            }
        }
    }
}

