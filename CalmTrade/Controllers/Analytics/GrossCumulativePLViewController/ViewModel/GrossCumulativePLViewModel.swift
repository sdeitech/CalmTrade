//
//  GrossCumulativePLViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 09/12/25.
//


import Foundation
import Combine

final class GrossCumulativePLViewModel {

    @Published private(set) var points: [CumulativePLPoint] = []
    @Published private(set) var loading = false
    @Published private(set) var errorMessage: String?

    private let api = APIService()
    private var cancellables = Set<AnyCancellable>()

    func fetchPL(range: String) {
        loading = true
        errorMessage = nil
        
        api.startService(
            with: .GET,
            path: "analytics/gross-cumulative-P&L",
            parameters: ["filter": range],
            files: nil,
            modelType: GrossCumulativePLResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.loading = false

                switch result {
                case .Success(let model):
                    guard let model, let arr = model.data else { return }

                    self?.points = arr.compactMap { dto in
                        let df = DateFormatter()
                        df.dateFormat = "yyyy-MM-dd"
                        guard let d = df.date(from: dto.date) else { return nil }
                        return CumulativePLPoint(date: d, value: dto.cumulativePnl)
                    }

                case .Error(let err):
                    self?.errorMessage = err
                }
            }
        }
    }
}
