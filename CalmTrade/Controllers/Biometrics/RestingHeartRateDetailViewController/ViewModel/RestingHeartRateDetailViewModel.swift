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
    private var centerDate: Date = Date()

    private var hasRecentPolar360RestingHeartRate: Bool {
        guard let latest = repo.latestValue(kind: .restingHeartRate, source: .polar360) else { return false }
        let age = Date().timeIntervalSince(latest.date)
        return age <= (14 * 86400)
    }

    private var preferredRhrSource: CTMetricSource? {
        switch DeviceManager.shared.currentSource {
        case .polar360:
            return .polar360
        case .polarH10:
            return hasRecentPolar360RestingHeartRate ? .polar360 : .appleHealth
        case .appleHealthKit:
            return hasRecentPolar360RestingHeartRate ? .polar360 : .appleHealth
        }
    }

    private var referenceDate: Date {
        repo.latestValue(kind: .restingHeartRate, source: preferredRhrSource)?.date ?? Date()
    }

    // MARK: - Public

    func fetchInitialData(for range: ChartTimeRange) {
        selectedRange = range
        centerDate = referenceDate
        loadForSelectedRange()
    }

    func refreshCurrentRange() {
        loadForSelectedRange()
    }

    @discardableResult
    func loadPreviousPeriod() -> Bool {
        centerDate = shift(center: centerDate, for: selectedRange, direction: -1)
        loadForSelectedRange()
        return true
    }

    @discardableResult
    func loadNextPeriod() -> Bool {
        let shifted = shift(center: centerDate, for: selectedRange, direction: 1)
        let nextCenterDate = min(shifted, referenceDate)
        let currentAnchor = periodAnchor(for: selectedRange, date: centerDate)
        let nextAnchor = periodAnchor(for: selectedRange, date: nextCenterDate)
        guard nextAnchor > currentAnchor else { return false }
        centerDate = nextCenterDate
        loadForSelectedRange()
        return true
    }

    // MARK: - Loading (repo-only)

    private func loadForSelectedRange() {
        onIsLoading?(true)

        let cal = Calendar.current
        let reference = referenceDate
        let (anchor, fetchEnd, displayEnd): (Date, Date, Date) = {
            switch selectedRange {
            case .daily:
                let startOfDay = cal.startOfDay(for: centerDate)
                let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
                return (startOfDay, min(endOfDay, reference), endOfDay)
            case .weekly:
                let startOfWeek = cal.dateInterval(of: .weekOfYear, for: centerDate)?.start ?? cal.startOfDay(for: centerDate)
                let endOfWeek = cal.date(byAdding: .day, value: 7, to: startOfWeek)!
                return (startOfWeek, min(endOfWeek, reference), endOfWeek)
            case .monthly:
                let startOfMonth = cal.dateInterval(of: .month, for: centerDate)?.start ?? cal.startOfDay(for: centerDate)
                let endOfMonth = cal.date(byAdding: .month, value: 1, to: startOfMonth)!
                return (startOfMonth, min(endOfMonth, reference), endOfMonth)
            }
        }()

        DispatchQueue.global(qos: .userInitiated).async {
            let samples = self.repo.series(kind: .restingHeartRate,
                                           from: anchor,
                                           to: fetchEnd,
                                           source: self.preferredRhrSource)

            // Bucket by range and compute average per bucket
            let bucketed = self.bucket(samples: samples, range: self.selectedRange)

            // Compute yMax and average text
            let maxV = bucketed.map(\.value).max() ?? 0
            let avgText: String = {
                guard !bucketed.isEmpty else { return "--" }
                let mean = bucketed.reduce(0.0, { $0 + $1.value }) / Double(bucketed.count)
                return "\(Int(round(mean)))"
            }()

            let header = self.headerString(for: self.selectedRange, start: anchor, end: displayEnd)

            DispatchQueue.main.async {
                self.points = bucketed
                self.xDomain = anchor ... displayEnd
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
                return cal.startOfDay(for: date)
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
            let displayEnd = cal.date(byAdding: .day, value: -1, to: end) ?? end
            let e = df.string(from: displayEnd)
            let y = cal.component(.year, from: displayEnd)
            return "\(s) - \(e), \(y)"
        case .monthly:
            df.dateFormat = "MMMM yyyy"
            return df.string(from: start)
        }
    }

    private func shift(center: Date, for range: ChartTimeRange, direction: Int) -> Date {
        let cal = Calendar.current
        switch range {
        case .daily:
            return cal.date(byAdding: .day, value: direction, to: center)!
        case .weekly:
            return cal.date(byAdding: .weekOfYear, value: direction, to: center)!
        case .monthly:
            return cal.date(byAdding: .month, value: direction, to: center)!
        }
    }

    private func periodAnchor(for range: ChartTimeRange, date: Date) -> Date {
        let cal = Calendar.current
        switch range {
        case .daily:
            return cal.startOfDay(for: date)
        case .weekly:
            return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        case .monthly:
            return cal.dateInterval(of: .month, for: date)?.start ?? date
        }
    }
}
