//
//  GrossDailyPnLViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 01/12/25.
//


import Foundation
import Combine

final class GrossDailyPnLViewModel {

    // Output for VC to bind
    @Published private(set) var bars: [DailyPnLBar] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let api = APIService()

    // MARK: - API Call
    func fetch(range: String) {
        isLoading = true
        errorMessage = nil

        api.startService(
            with: .GET,
            path: "analytics/gross-daily-P&L",
            parameters: ["filter" : range],
            files: nil,
            modelType: GrossDailyPnLResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                self.isLoading = false

                switch result {
                case .Success(let res):
                    guard let res, let items = res.data else {
                        self.bars = []
                        return
                    }
                    self.bars = items.compactMap { entry in
                        if let d = Self.parseISO(entry.date) {
                            return DailyPnLBar(date: d, value: entry.pnl)
                        }
                        return nil
                    }

                case .Error(let msg):
                    self.errorMessage = msg
                    self.bars = []
                }
            }
        }
    }

    // MARK: - ISO → Date
    static func parseISO(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = .current
        f.timeZone = .current
        return f.date(from: s)
    }
}
