//
//  NoTradeViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 26/12/25.
//


import Foundation

final class NoTradeViewModel: ObservableObject {

    // MARK: - Inputs
    @Published var symbol: String = ""
    @Published var entryPrice: String = ""
    @Published var reason: String = ""

    // MARK: - Outputs
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var didSave: Bool = false

    // MARK: - Dependencies
    private let api: ApiServiceProtocol
    private let sessionId: String

    init(sessionId: String, api: ApiServiceProtocol = APIService()) {
        self.sessionId = sessionId
        self.api = api
    }

    // MARK: - Actions
    func save() {
        guard !symbol.isEmpty, !reason.isEmpty else {
            errorMessage = "Please fill all fields"
            return
        }

        isLoading = true
        errorMessage = nil

        let params: [String: Any] = [
            "entryPrice": entryPrice,
            "symbol": symbol,
            "reason": reason
        ]

        api.startService(
            with: .POST,
            path: "session/no-trades",
            parameters: params,
            files: nil,
            modelType: NoTradeResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .Success(let response):
                    if response?.success == false {
                        self?.errorMessage = response?.message ?? "Something went wrong"
                    } else {
                        self?.didSave = true
                    }

                case .Error(let message):
                    self?.errorMessage = message
                }
            }
        }
    }
}
