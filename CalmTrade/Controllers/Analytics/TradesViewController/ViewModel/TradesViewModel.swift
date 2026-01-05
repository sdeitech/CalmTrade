//
//  TradesViewModel.swift
//  CalmTrade
//

import Foundation
import UIKit

final class TradesViewModel {

    var onLoading: ((Bool) -> Void)?
    var onError: ((String) -> Void)?
    var onData: (([TradeItem]) -> Void)?

    private let api = APIService()
    private var currentMonth: Int = 10
    private var currentYear: Int = 2025

    func load(month: Int, year: Int) {
        currentMonth = month
        currentYear = year
        fetchTrades()
    }

    func refresh() {
        fetchTrades()
    }

    private func fetchTrades() {
        onLoading?(true)

        let params: [String: Any] = [
            "month": currentMonth,
            "year": currentYear
        ]

        api.startService(
            with: .GET,
            path: "analytics/tradeList",
            parameters: nil,
            files: nil,
            modelType: TradeListResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoading?(false)

                switch result {
                case .Success(let res):
                    self?.onData?(res?.data ?? [])
                case .Error(let err):
                    self?.onError?(err)
                }
            }
        }
    }
}
