//
//  HRVDetailViewModel.swift
//  CalmTrade
//
//  Updated: repo-only (no HealthKit). Buckets local RMSSD/SDNN for CalmScore-style range chart.
//  - Supports RMSSD or SDNN (set via `set(metric:)`)
//  - Timeframes mirror HeartRate detail (Hourly/Daily/Weekly/Monthly/Yearly)
//  - Produces min/max “range bars” per bucket
//

import Foundation
import Combine

enum HRVMetricType { case rmssd, sdnn }

final class HRVDetailViewModel: ObservableObject {

    // MARK: - Time ranges (match HR)
    enum ChartTimeRange: Int, CaseIterable {
        case hourly = 0, daily, weekly, monthly, yearly
        var title: String {
            switch self {
            case .hourly:  return "Hourly"
            case .daily:   return "Daily"
            case .weekly:  return "Weekly"
            case .monthly: return "Monthly"
            case .yearly:  return "Yearly"
            }
        }
    }

    // MARK: - Outputs
    @Published var points: [HRVRangeCalmChartView.HRVRangePoint] = []
    @Published var averageText: String = "--"      // average of bucket midpoints
    @Published var dateRangeText: String = "--"
    @Published var yMax: Double = 600
    @Published var currentChartRange: ChartTimeRange = .hourly
    
    var hrvDetailText : String {
        let rmssdText = "Heart Rate Variability (HRV) measures the variation in time between each heartbeat. With Polar 360 and Polar H10 devices, HRV is derived using RMSSD (Root Mean Square of Successive Differences) from inter-beat interval (IBI) data. RMSSD reflects the activity of the parasympathetic nervous system, providing insight into your recovery, stress, and overall autonomic balance."
        let sdnnText = "Heart Rate Variability (HRV) measures the variation in time between each heartbeat. For Polar 360 and Polar H10 devices, HRV is calculated using SDNN (Standard Deviation of NN intervals) derived from inter-beat interval (IBI) data. SDNN reflects overall autonomic nervous system activity, including both sympathetic and parasympathetic branches.\nIf you use Apple Watch, SDNN values are fetched directly from Apple Health and displayed in the app."
        return metric == .rmssd ? rmssdText : sdnnText
    }

    var onIsLoading: ((Bool) -> Void)?

    // MARK: - Private
    private let repo = CTMetricsRepository.shared
    private(set) var metric: HRVMetricType = .rmssd
    private(set) var selectedRange: ChartTimeRange = .hourly
    private(set) var centerDate: Date = Date()
    private var isLoading = false { didSet { onIsLoading?(isLoading) } }

    var xDomain: ClosedRange<Date> { makeXDomain(for: selectedRange, center: centerDate) }

    // MARK: - Configure
    func set(metric: HRVMetricType) { self.metric = metric }

    // MARK: - Entry points
    func fetch(for range: ChartTimeRange) {
        selectedRange = range
        currentChartRange = range
        centerDate = Date()
        let domain = makeXDomain(for: range, center: centerDate)
        load(start: domain.lowerBound, end: domain.upperBound, range: range)
    }

    @discardableResult
    func loadPreviousPeriod() -> Bool {
        guard !isLoading else { return false }
        centerDate = shift(center: centerDate, for: selectedRange, direction: -1)
        let d = makeXDomain(for: selectedRange, center: centerDate)
        load(start: d.lowerBound, end: d.upperBound, range: selectedRange)
        return true
    }

    @discardableResult
    func loadNextPeriod() -> Bool {
        guard !isLoading else { return false }
        let shifted = min(shift(center: centerDate, for: selectedRange, direction: +1), Date())
        let currentAnchor = periodAnchor(for: selectedRange, date: centerDate)
        let nextAnchor = periodAnchor(for: selectedRange, date: shifted)
        guard nextAnchor > currentAnchor else { return false }
        centerDate = shifted
        let d = makeXDomain(for: selectedRange, center: centerDate)
        load(start: d.lowerBound, end: d.upperBound, range: selectedRange)
        return true
    }

    // MARK: - Core load
    private func load(start: Date, end: Date, range: ChartTimeRange) {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let kind: CTMetricKind = (self.metric == .rmssd) ? .rmssd : .sdnn
            // Detached value structs (safe for background use)
            let samples: [CTMetricsRepository.CTBiometricPoint] =
                self.repo.series(kind: kind, from: start, to: end, source: nil)

            let bucketed = self.bucket(samples: samples, for: range)
            let sorted = bucketed.sorted(by: { $0.time < $1.time })

            let maxU = sorted.map(\.max).max() ?? 0
            let yTop = self.pickHRVTop(maxU)
            let header = self.headerText(range: range, domain: start...end)

            let avgMid: Double? = {
                guard !sorted.isEmpty else { return nil }
                let mids = sorted.map { ($0.min + $0.max) / 2.0 }
                return mids.reduce(0, +) / Double(mids.count)
            }()

            DispatchQueue.main.async {
                self.points = sorted
                self.yMax = yTop
                self.averageText = avgMid.map { "\(Int(($0).rounded()))" } ?? "--"
                self.dateRangeText = header
                self.isLoading = false
            }
        }
    }

    // MARK: - Bucketing (same cadence rules as HR)
    private func bucket(
        samples: [CTMetricsRepository.CTBiometricPoint],
        for range: ChartTimeRange
    ) -> [HRVRangeCalmChartView.HRVRangePoint] {

        guard !samples.isEmpty else { return [] }
        let cal = Calendar.current

        // Group by bucket start date
        let grouped = Dictionary(grouping: samples) { s -> Date in
            switch range {
            case .hourly:
                let hourStart = cal.dateInterval(of: .hour, for: s.date)?.start ?? cal.startOfDay(for: s.date)
                let minute = cal.component(.minute, from: s.date)
                let idx = minute / 3
                return cal.date(byAdding: .minute, value: idx * 3, to: hourStart) ?? hourStart

            case .daily:
                return cal.dateInterval(of: .hour, for: s.date)?.start ?? s.date

            case .weekly:
                return cal.startOfDay(for: s.date)

            case .monthly:
                return cal.startOfDay(for: s.date)

            case .yearly:
                return cal.dateInterval(of: .month, for: s.date)?.start ?? cal.startOfDay(for: s.date)
            }
        }

        // Compute min/max for each bucket
        var out: [HRVRangeCalmChartView.HRVRangePoint] = []
        out.reserveCapacity(grouped.count)

        for (bucketStart, items) in grouped {
            let vals = items.map(\.value)
            if let lo = vals.min(), let hi = vals.max() {
                out.append(.init(time: bucketStart, min: lo, max: hi))
            }
        }

        return out
    }

    // MARK: - Domains/paging (same behavior as HeartRateDetailViewModel)
    private func makeXDomain(for range: ChartTimeRange, center: Date) -> ClosedRange<Date> {
        let cal = Calendar.current
        switch range {
        case .hourly:
            let startOfHour = cal.dateInterval(of: .hour, for: center)?.start ?? center
            let endOfHour = cal.date(byAdding: .minute, value: 60, to: startOfHour)!
            return startOfHour...min(endOfHour, Date())
        case .daily:
            let startOfDay = cal.startOfDay(for: center)
            let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
            return startOfDay...min(endOfDay, Date())
        case .weekly:
            let week = cal.dateInterval(of: .weekOfYear, for: center)!
            let s = week.start
            let e = cal.date(byAdding: .day, value: 7, to: s)!
            return s...min(e, Date())
        case .monthly:
            let month = cal.dateInterval(of: .month, for: center)!
            let s = month.start
            let e = cal.date(byAdding: .month, value: 1, to: s)!
            return s...min(e, Date())
        case .yearly:
            let year = cal.dateInterval(of: .year, for: center)!
            let s = year.start
            let e = cal.date(byAdding: .year, value: 1, to: s)!
            return s...min(e, Date())
        }
    }

    private func shift(center: Date, for range: ChartTimeRange, direction: Int) -> Date {
        let cal = Calendar.current
        switch range {
        case .hourly:  return cal.date(byAdding: .hour, value: direction, to: center)!
        case .daily:   return cal.date(byAdding: .day, value: direction, to: center)!
        case .weekly:  return cal.date(byAdding: .weekOfYear, value: direction, to: center)!
        case .monthly: return cal.date(byAdding: .month, value: direction, to: center)!
        case .yearly:  return cal.date(byAdding: .year, value: direction, to: center)!
        }
    }

    private func periodAnchor(for range: ChartTimeRange, date: Date) -> Date {
        let cal = Calendar.current
        switch range {
        case .hourly:
            return cal.dateInterval(of: .hour, for: date)?.start ?? date
        case .daily:
            return cal.startOfDay(for: date)
        case .weekly:
            return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? cal.startOfDay(for: date)
        case .monthly:
            return cal.dateInterval(of: .month, for: date)?.start ?? cal.startOfDay(for: date)
        case .yearly:
            return cal.dateInterval(of: .year, for: date)?.start ?? cal.startOfDay(for: date)
        }
    }

    private func headerText(range: ChartTimeRange, domain: ClosedRange<Date>) -> String {
        let fmt = DateFormatter()
        let s = domain.lowerBound
        let e = domain.upperBound
        switch range {
        case .hourly:
            fmt.dateFormat = "MMMM d, yyyy"
            return fmt.string(from: centerDate)
        case .daily:
            fmt.dateFormat = "MMMM d, yyyy"
            return fmt.string(from: centerDate)
        case .weekly:
            fmt.dateFormat = "MMM d"
            let end = Calendar.current.date(byAdding: .day, value: -1, to: e) ?? e
            return "\(fmt.string(from: s)) - \(fmt.string(from: end))"
        case .monthly:
            fmt.dateFormat = "MMMM yyyy"
            return fmt.string(from: s)
        case .yearly:
            fmt.dateFormat = "yyyy"
            return fmt.string(from: s)
        }
    }

    // MARK: - Local helper (axis top selection for HRV)
    @inline(__always)
    private func pickHRVTop(_ rangeMax: Double) -> Double {
        let step = 200.0
        let safe = max(0.0, rangeMax)
        let top = ceil(safe / step) * step
        return max(step, top) // at least 200
    }
}
