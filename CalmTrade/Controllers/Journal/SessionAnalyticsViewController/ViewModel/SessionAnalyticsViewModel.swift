//
//  SessionAnalyticsViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 13/01/26.
//


import Foundation

final class SessionAnalyticsViewModel {

    // MARK: - Output bindings
    var onLoading: ((Bool) -> Void)?
    var onError: ((String) -> Void)?
    var onUpdate: (() -> Void)?

    // MARK: - Data
    private(set) var data: SessionAnalyticsData?

    private let api: ApiServiceProtocol = APIService()

    // MARK: - API
    func fetch(date: String) {
        onLoading?(true)
        
        api.startService(
            with: .GET,
            path: "session/analytics",
            parameters: ["date": date],
            files: nil,
            modelType: SessionAnalyticsResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoading?(false)
                
                switch result {
                case .Success(let response):
                    guard let payload = response?.data else {
                        self?.onError?("Invalid analytics response")
                        return
                    }
                    self?.data = payload
                    self?.onUpdate?()
                    
                case .Error(let message):
                    self?.onError?(message)
                }
            }
        }
    }
}
