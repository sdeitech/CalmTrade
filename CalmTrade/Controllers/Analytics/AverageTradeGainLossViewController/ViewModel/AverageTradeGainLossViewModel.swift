//
//  AverageTradeGainLossViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/12/25.
//


import Foundation

final class AverageTradeGainLossViewModel {

    private let api = APIService()

    // OUTPUT BINDINGS
    var onLoading: ((Bool) -> Void)?
    var onData: ((AverageTradeGainLossResponse) -> Void)?
    var onError: ((String) -> Void)?

    func fetch(filter: String) {
        onLoading?(true)

        api.startService(
            with: .GET,
            path: "analytics/averageTrade-G&L",
            parameters: ["filter": filter],
            files: nil,
            modelType: AverageTradeGainLossResponse.self
        ) { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                self.onLoading?(false)

                switch result {
                case .Success(let model):
                    if let data = model {
                        self.onData?(data)
                    } else {
                        self.onError?("Invalid API response")
                    }

                case .Error(let message):
                    self.onError?(message)
                }
            }
        }
    }
}
