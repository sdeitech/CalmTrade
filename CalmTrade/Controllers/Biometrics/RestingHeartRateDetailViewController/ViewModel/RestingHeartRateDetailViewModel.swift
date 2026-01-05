//
//  RestingHeartRateDetailViewModel.swift
//  CalmTrade
//

import Foundation
import Combine

final class RestingHeartRateDetailViewModel: ObservableObject {

    enum ChartTimeRange: Int, CaseIterable { case daily = 0, weekly, monthly }

    // Outputs the VC binds to
    @Published var points: [RestingHRPoint] = []
    @Published var xDomain: ClosedRange<Date> = Date()...Date()
    @Published var yMax: Double = 0
    @Published var headerDateText: String = ""
    @Published var averageText: String = "--"
    @Published var selectedRange: ChartTimeRange = .weekly

    var onIsLoading: ((Bool) -> Void)?

    // Repo
    private let repo = CTMetricsRepository.shared

    // MARK: - Public

    func fetchInitialData(for range: ChartTimeRange) {
        selectedRange = range
        loadForSelectedRange()
    }

    // MARK: - Loading (repo-only)

    private func loadForSelectedRange() {
        onIsLoading?(true)

        let cal = Calendar.current
        let end = Date()

        let (anchor, xEnd): (Date, Date) = {
            switch selectedRange {
            case .daily:
                let startOfDay = cal.startOfDay(for: end)
                let xEnd = cal.date(byAdding: .day, value: 1, to: startOfDay)! // next midnight
                return (startOfDay, xEnd)
            case .weekly:
                let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: end))!
                let xEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: end))!
                return (startOfWeek, xEnd)
            case .monthly:
                let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: end))!
                let nextMonth = cal.date(byAdding: .month, value: 1, to: startOfMonth)!
                return (startOfMonth, nextMonth)
            }
        }()

        DispatchQueue.global(qos: .userInitiated).async {
            // Fetch samples from local store (detached structs)
            let samples = self.repo.series(kind: .restingHeartRate,
                                           from: anchor,
                                           to: end,
                                           source: nil)

            // Bucket by range and compute average per bucket
            let bucketed = self.bucket(samples: samples, range: self.selectedRange)

            // Compute yMax and average text
            let maxV = bucketed.map(\.value).max() ?? 0
            let avgText: String = {
                guard !bucketed.isEmpty else { return "--" }
                let mean = bucketed.reduce(0.0, { $0 + $1.value }) / Double(bucketed.count)
                return "\(Int(round(mean)))"
            }()

            let header = self.headerString(for: self.selectedRange, start: anchor, end: end)

            DispatchQueue.main.async {
                self.points = bucketed
                self.xDomain = anchor ... xEnd
                self.yMax = maxV
                self.averageText = avgText
                self.headerDateText = header
                self.onIsLoading?(false)
            }
        }
    }

    private func bucket(samples: [CTMetricsRepository.CTBiometricPoint],
                        range: ChartTimeRange) -> [RestingHRPoint] {
        guard !samples.isEmpty else { return [] }
        let cal = Calendar.current

        func bucketStart(for date: Date) -> Date {
            switch range {
            case .daily:
                return cal.dateInterval(of: .hour, for: date)?.start ?? date
            case .weekly:
                return cal.startOfDay(for: date)
            case .monthly:
                return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? cal.startOfDay(for: date)
            }
        }

        // Group by bucket start
        let grouped = Dictionary(grouping: samples, by: { bucketStart(for: $0.date) })

        // Average per bucket
        var out: [RestingHRPoint] = []
        out.reserveCapacity(grouped.count)
        for (k, arr) in grouped {
            let vals = arr.map { $0.value }
            guard !vals.isEmpty else { continue }
            let mean = vals.reduce(0.0, +) / Double(vals.count)
            out.append(.init(time: k, value: mean))
        }

        return out.sorted { $0.time < $1.time }
    }

    // MARK: - UI helpers

    private func headerString(for range: ChartTimeRange, start: Date, end: Date) -> String {
        let df = DateFormatter()
        let cal = Calendar.current
        switch range {
        case .daily:
            df.dateFormat = "MMM d, yyyy"
            return df.string(from: start)
        case .weekly:
            df.dateFormat = "MMM d"
            let s = df.string(from: start)
            let e = df.string(from: cal.date(byAdding: .day, value: 6, to: start)!)
            let y = cal.component(.year, from: end)
            return "\(s) - \(e), \(y)"
        case .monthly:
            df.dateFormat = "MMMM yyyy"
            return df.string(from: start)
        }
    }
}
