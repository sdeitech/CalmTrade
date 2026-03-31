//
//  HeartRateDetailViewModel.swift
//  CalmTrade
//
//  Repo-only (no HealthKit). Buckets local HR samples for CalmScore-style SwiftUI chart.
//  - Yearly tab
//  - Centered paging per mode
//  - Explicit domains & ticks for stable X-axis labeling
//

import Foundation
import Combine

// MARK: - Point model for the SwiftUI chart (internal)
struct HeartPoint: Identifiable, Hashable {
    var id: Double { time.timeIntervalSince1970 }  // stable id per bucket
    let time: Date                                 // bucket start time
    let min: Double                                // min BPM in bucket
    let max: Double                                // max BPM in bucket
    var med: Double { (min + max) / 2.0 }
}

// MARK: - ViewModel
final class HeartRateDetailViewModel: ObservableObject {

    // MARK: - Time Ranges (segments)
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

    // MARK: - Outputs (bind to labels / chart)
    @Published var points: [HeartPoint] = []          // feed into SwiftUI chart
    @Published var headerDateText: String = ""        // e.g. “Sep 11, 2025” or a range
    @Published var rangeText: String = "--"           // e.g. “52 – 89 BPM”
    @Published var latestTimeText: String = "--"      // e.g. “6:04 AM”
    @Published var latestValueText: String = "--"     // e.g. “67”
    var onIsLoading: ((Bool) -> Void)?
    
    // MARK: - Private
    private let repo = CTMetricsRepository.shared
    private(set) var selectedRange: ChartTimeRange = .hourly
    private(set) var centerDate: Date = Date()        // time we try to keep centered per window
    private var isLoadingData = false { didSet { onIsLoading?(isLoadingData) } }
    private var liveHubToken: UUID?

    // MARK: - Derived axis inputs (consumed by VC/SwiftUI)
    var xDomain: ClosedRange<Date> { makeXDomain(for: selectedRange, center: centerDate) }
    var xAxisTicks: [Date] { makeXTicks(for: selectedRange, domain: xDomain) }

    // MARK: - Public API

    /// Call when the screen appears or the segment changes.
    func fetchInitialData(for range: ChartTimeRange) {
        selectedRange = range
        centerDate = Date()
        loadData(for: range)
    }

    /// Page to the previous period (keeps window size, shifts center left).
    @discardableResult
    func loadPreviousPeriod() -> Bool {
        guard !isLoadingData else { return false }
        centerDate = shift(center: centerDate, for: selectedRange, direction: -1)
        loadData(for: selectedRange)
        return true
    }

    /// Page to the next period (capped at now).
    @discardableResult
    func loadNextPeriod() -> Bool {
        guard !isLoadingData else { return false }
        let shifted = shift(center: centerDate, for: selectedRange, direction: +1)
        let nextCenterDate = min(shifted, Date())
        let currentAnchor = periodAnchor(for: selectedRange, date: centerDate)
        let nextAnchor = periodAnchor(for: selectedRange, date: nextCenterDate)
        guard nextAnchor > currentAnchor else { return false }
        centerDate = nextCenterDate
        loadData(for: selectedRange)
        return true
    }

    // MARK: - Core loading (repo-only)

    private func loadData(for range: ChartTimeRange) {
        isLoadingData = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let domain = self.makeXDomain(for: range, center: self.centerDate)
            let samples = self.repo.series(kind: .heartRate,
                                           from: domain.lowerBound,
                                           to: domain.upperBound,
                                           source: nil)
            let bucketed = self.bucket(samples: samples, for: range)
            let sorted = bucketed.sorted(by: { $0.time < $1.time })
            
            DispatchQueue.main.async {
                self.finishUpdate(with: sorted, domain: domain)
            }
        }
    }


    // MARK: - Bucketing

    private func bucket(samples: [CTMetricsRepository.CTBiometricPoint], for range: ChartTimeRange) -> [HeartPoint] {
        guard !samples.isEmpty else { return [] }
        let cal = Calendar.current

        // Group by bucket start date
        let grouped = Dictionary(grouping: samples) { s -> Date in
            bucketStart(for: s.date, range: range, calendar: cal)
        }

        // Compute min/max BPM for each bucket
        var pts: [HeartPoint] = []
        pts.reserveCapacity(grouped.count)
        for (bucketStart, items) in grouped {
            let bpms = items.map { $0.value }
            guard let min = bpms.min(), let max = bpms.max() else { continue }
            pts.append(HeartPoint(time: bucketStart, min: min, max: max))
        }
        return pts
    }

    private func bucketStart(for date: Date, range: ChartTimeRange, calendar cal: Calendar) -> Date {
        switch range {
        case .hourly:
            // 3-minute buckets within the hour that 'date' falls in
            let hourStart = cal.dateInterval(of: .hour, for: date)?.start ?? cal.startOfDay(for: date)
            let minute = cal.component(.minute, from: date)
            let index = minute / 3                    // 0…19
            return cal.date(byAdding: .minute, value: index * 3, to: hourStart) ?? hourStart

        case .daily:
            return cal.dateInterval(of: .hour, for: date)?.start ?? date

        case .weekly:
            // Daily buckets for Weekly view (7 columns like CalmScore)
            return cal.startOfDay(for: date)

        case .monthly:
            // Daily buckets across the month
            return cal.startOfDay(for: date)

        case .yearly:
            // Yearly view uses monthly buckets (12 per year)
            return cal.dateInterval(of: .month, for: date)?.start ?? cal.startOfDay(for: date)
        }
    }

    // MARK: - Finish / UI mapping

    private func finishUpdate(with newPoints: [HeartPoint], domain: ClosedRange<Date>) {
        // Only update chart + range labels here.
        // Latest HR/time are driven live via startLiveHR() so they stay independent of timeframe.
        let all = newPoints.flatMap { [$0.min, $0.max] }
        let minVal = Int(all.min() ?? 0)
        let maxVal = Int(all.max() ?? 0)
        let header = formatDateRangeHeader(for: selectedRange, domain: domain)

        DispatchQueue.main.async {
            self.points = newPoints
            self.rangeText = (minVal == 0 && maxVal == 0) ? "--" : "\(minVal) – \(maxVal) BPM"
            self.headerDateText = header
            self.isLoadingData = false
        }
    }
    
    func startLiveHR() {
        // Prevent duplicate listeners
        if liveHubToken != nil { return }

        liveHubToken = CalmScoreHub.shared.addListener { [weak self] _, _, props in
            guard let self else { return }
            let bpm = Int(round(props.trend.hrBpm))
            let ts = props.lastUpdate
            DispatchQueue.main.async {
                self.latestValueText = bpm > 0 ? "\(bpm)" : "--"
                self.latestTimeText = self.formatTime(ts)
            }
        }
    }

    func stopLiveHR() {
        if let t = liveHubToken {
            CalmScoreHub.shared.removeListener(t)
            liveHubToken = nil
        }
    }

    // MARK: - Domains & Ticks

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
            // 1-month window (calendar month of center)
            let month = cal.dateInterval(of: .month, for: center)!
            let s = month.start
            let e = cal.date(byAdding: .month, value: 1, to: s)!
            return s...min(e, Date())

        case .yearly:
            // 1-year window (calendar year of center)
            let year = cal.dateInterval(of: .year, for: center)!
            let s = year.start
            let e = cal.date(byAdding: .year, value: 1, to: s)!
            return s...min(e, Date())
        }
    }

    private func makeXTicks(for range: ChartTimeRange, domain: ClosedRange<Date>) -> [Date] {
        let cal = Calendar.current
        var ticks: [Date] = []

        func stride(_ comp: Calendar.Component, step: Int) {
            var t = cal.dateInterval(of: comp, for: domain.lowerBound)?.start ?? domain.lowerBound
            while t <= domain.upperBound {
                ticks.append(t)
                t = cal.date(byAdding: comp, value: step, to: t) ?? domain.upperBound.addingTimeInterval(1)
            }
        }

        switch range {
        case .hourly:  stride(.hour, step: 1)         // each hour
        case .daily:   stride(.day, step: 1)          // each day
        case .weekly:  stride(.weekOfYear, step: 1)   // each week
        case .monthly: stride(.month, step: 1)        // each month
        case .yearly:  stride(.year, step: 1)         // each year (even though we bucket monthly)
        }
        return ticks
    }

    private func shift(center: Date, for range: ChartTimeRange, direction: Int) -> Date {
        let cal = Calendar.current
        switch range {
        case .hourly:
            return cal.date(byAdding: .hour, value: direction, to: center)!
        case .daily:
            return cal.date(byAdding: .day, value: direction, to: center)!
        case .weekly:
            return cal.date(byAdding: .weekOfYear, value: direction, to: center)!
        case .monthly:
            return cal.date(byAdding: .month, value: direction, to: center)!
        case .yearly:
            return cal.date(byAdding: .year, value: direction, to: center)!
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

    // MARK: - Headers & Formatting

    private func formatDateRangeHeader(for range: ChartTimeRange, domain: ClosedRange<Date>) -> String {
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

    private func formatTime(_ date: Date?) -> String {
        guard let date else { return "--" }
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date)
    }
}

// MARK: - X-axis label format for SwiftUI Chart (internal)
extension HeartRateDetailViewModel.ChartTimeRange {
    var xLabelFormat: Date.FormatStyle {
        switch self {
        case .hourly:  return .dateTime.hour()
        case .daily:   return .dateTime.hour()
        case .weekly:  return .dateTime.weekday(.abbreviated)
        case .monthly: return .dateTime.month(.abbreviated)
        case .yearly:  return .dateTime.year()
        }
    }
}
