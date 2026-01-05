//
//  AnalyticsDashboardViewModel.swift
//  CalmTrade
//

import Foundation
import Combine

final class AnalyticsDashboardViewModel {

    // MARK: - Published Outputs
    @Published private(set) var timeframe: AnalyticsTimeframe = .recent

    @Published private(set) var winRateScore: Double = 0
    @Published private(set) var winRateAvgCalmScore: String = "--"

    @Published private(set) var cumulativePL: [CumulativePLPoint] = []
    @Published private(set) var grossDailyPnL: [DailyPnLBar] = []
    
    // Avg Trade Gain & Loss
    @Published private(set) var avgGain: Double = 0
    @Published private(set) var avgLoss: Double = 0

    // Profit Factor
    @Published private(set) var profitFactor: Double = 0

    // Consecutive
    @Published private(set) var longestWin: Int = 0
    @Published private(set) var longestLoss: Int = 0
    
    // Actual win/loss from winRate object
    @Published private(set) var totalWins: Int = 0
    @Published private(set) var totalLosses: Int = 0

    // Average Hold Time
    @Published private(set) var holdWin: String = "--"
    @Published private(set) var holdLoss: String = "--"

    private let api = APIService()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init() { }

    // MARK: - DASHBOARD API
    func fetchDashboard() {
        api.startService(
            with: .GET,
            path: "analytics/stats-dashboard",
            parameters: nil,
            files: nil,
            modelType: StatsDashboardResponse.self
        ) { [weak self] result in
            switch result {
            case .Success(let model):
                guard let dto = model else { return }
                DispatchQueue.main.async { self?.applyDashboardAPI(dto) }

            case .Error(let message):
                print("❌ Dashboard API Error:", message)
            }
        }
    }

    private func applyDashboardAPI(_ dto: StatsDashboardResponse) {

        // WIN RATE
        winRateScore = Double(dto.winRate.winRate)
        winRateAvgCalmScore = "\(dto.winRate.avgCalmScore)"
        totalWins = dto.winRate.wins
        totalLosses = dto.winRate.losses

        let formatter = ISO8601DateFormatter()

        cumulativePL = dto.cumulativePnL.data.compactMap { item in
            formatter.date(from: item.date + "T00:00:00Z")
                .map { CumulativePLPoint(date: $0, value: item.value) }
        }

        avgGain = dto.avgGainLoss.avgGain
        avgLoss = dto.avgGainLoss.avgLoss

        profitFactor = dto.profitFactor.profitFactor

        longestWin = dto.consecutive.longestWin
        longestLoss = dto.consecutive.longestLoss

        let wM = dto.avgHoldTime.winning.minutes
        let wS = dto.avgHoldTime.winning.seconds
        holdWin = "\(wM)m \(wS)s"

        let lM = dto.avgHoldTime.losing.minutes
        let lS = dto.avgHoldTime.losing.seconds
        holdLoss = "\(lM)m \(lS)s"
    }


    // MARK: - GROSS DAILY PNL API
    func fetchGrossDailyPnL(filter: String = "monthly") {

        let params = ["filter": filter]

        api.startService(
            with: .GET,
            path: "analytics/gross-daily-P&L",
            parameters: params,
            files: nil,
            modelType: GrossDailyPnLResponse.self
        ) { [weak self] result in
            switch result {
            case .Success(let model):
                guard let dto = model else { return }
                DispatchQueue.main.async { self?.applyGrossDailyPnLAPI(dto) }

            case .Error(let message):
                print("❌ Gross Daily P&L API Error:", message)
            }
        }
    }

    private func applyGrossDailyPnLAPI(_ dto: GrossDailyPnLResponse) {

        let formatter = ISO8601DateFormatter()

        grossDailyPnL = (dto.data?.compactMap { item in
            formatter.date(from: item.date + "T00:00:00Z")
                .map { DailyPnLBar(date: $0, value: item.pnl) }
        })!
    }

    // MARK: - Timeframe Change
    func setTimeframe(_ newValue: AnalyticsTimeframe) {
        timeframe = newValue
        
        if newValue == .recent {
            fetchGrossDailyPnL(filter: "monthly")
        }
    }
}
