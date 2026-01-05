//
//  WinRateViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 27/11/25.
//


import Foundation
import Combine

final class WinRateViewModel {

    enum Filter: String {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
        case yearly = "yearly"
    }

    // OUTPUT
    @Published var winRate: Int = 0
    @Published var wins: Int = 0
    @Published var losses: Int = 0
    @Published var trendPercent: Int = 0
    @Published var avgCalmScore: Int = 0

    private let api = APIService()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - API CALL
    func fetch(filter: Filter) {
        let path = "analytics/win-rate?filter=\(filter.rawValue)"

        api.startService(
            with: .GET,
            path: path,
            parameters: nil,
            files: nil,
            modelType: WinRateResponse.self
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .Success(let model):
                    guard let m = model else { return }
                    self.winRate = m.winRate ?? 0
                    self.wins = m.wins ?? 0
                    self.losses = m.losses ?? 0
                    self.trendPercent = m.changeFromLastPeriod ?? 0
                    self.avgCalmScore = m.avgCalmScore ?? 0

                case .Error(let msg):
                    print("WinRate API Error:", msg)
                }
            }
        }
    }
}
