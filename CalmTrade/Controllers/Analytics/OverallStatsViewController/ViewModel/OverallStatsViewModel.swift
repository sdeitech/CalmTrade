//
//  OverallStatsViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 10/11/25.
//


import Foundation
import Combine

@MainActor
final class OverallStatsViewModel: ObservableObject {
    
    @Published private(set) var stats: OverallStatsData?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    
    private let api = APIService()
    
    func fetchOverallStats(accountId: String, from: Date, to: Date) {
        isLoading = true
        errorMessage = nil
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let params: [String: Any] = [
            "accountId": accountId,
            "from": isoFormatter.string(from: from),
            "to": isoFormatter.string(from: to)
        ]
        
        api.startService(
            with: .GET,
            path: "analytics/overallStats",
            parameters: nil,
            files: nil,
            modelType: OverallStatsResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .Success(let response):
                    guard let data = response?.data else {
                        self?.errorMessage = "No data found"
                        return
                    }
                    self?.stats = data
                case .Error(let message):
                    self?.errorMessage = message
                }
            }
        }
    }
}
