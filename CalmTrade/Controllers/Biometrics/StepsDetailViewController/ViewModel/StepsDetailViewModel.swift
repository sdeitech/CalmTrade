//
//  StepsDetailViewModel.swift
//  CalmTrade
//

import Foundation
import Combine
import UIKit

final class StepsDetailViewModel: ObservableObject {

    enum ChartTimeRange: CaseIterable { case daily, weekly, monthly }

    // MARK: - Outputs
    @Published var bars: [StepBar] = []
    @Published var rangeText: String = "--"
    @Published var headerDateText: String = "--"
    @Published var averageText: String = "--"
    @Published var xDomain: ClosedRange<Date> = Date()...Date()
    @Published var yMax: Double = 0

    // MARK: - Private
    private let calendar = Calendar.current
    private(set) var currentRange: ChartTimeRange = .daily
    private(set) var centerDate: Date = Date()
    private var observersInstalled = false

    // MARK: - Lifecycle / entry points
    func fetchInitialData(for range: ChartTimeRange) {
        currentRange = range
        centerDate = Date()
        _installObserversIfNeeded()
        loadCurrentWindow()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Load
    func load(range: ChartTimeRange) {
        currentRange = range
        centerDate = Date()
        loadCurrentWindow()
    }

    @discardableResult
    func loadPreviousPeriod() -> Bool {
        centerDate = shift(center: centerDate, for: currentRange, direction: -1)
        loadCurrentWindow()
        return true
    }

    @discardableResult
    func loadNextPeriod() -> Bool {
        let shifted = shift(center: centerDate, for: currentRange, direction: +1)
        let nextCenterDate = min(shifted, Date())
        let currentAnchor = periodAnchor(for: currentRange, date: centerDate)
        let nextAnchor = periodAnchor(for: currentRange, date: nextCenterDate)
        guard nextAnchor > currentAnchor else { return false }
        centerDate = nextCenterDate
        loadCurrentWindow()
        return true
    }

    private func loadCurrentWindow() {
        let range = currentRange
        let (start, end) = window(for: range, center: centerDate)
        xDomain = start...end

        DispatchQueue.global(qos: .userInitiated).async {
            // ✅ unified, priority-aware minute series
            let minutes = StepEngine.seriesPerMinute(from: start, to: end)

            // Bucket into hour/day/7-day windows
            let grouped = Dictionary(grouping: minutes) { pair -> Date in
                self.bucketStart(for: pair.0, within: start...end, range: range)
            }

            var items: [StepBar] = []
            items.reserveCapacity(grouped.count)
            for (bucketStart, arr) in grouped {
                let sum = arr.reduce(0) { $0 + Double($1.1) }
                items.append(.init(time: bucketStart, value: sum))
            }
            items.sort { $0.time < $1.time }

            let total = items.reduce(0.0) { $0 + $1.value }
            let avg = items.isEmpty ? 0 : (total / Double(items.count))
            let yMax = items.map(\.value).max() ?? 0
            let header = self.headerTitle(range: range, start: start, end: end)
            let summaryValue: Int
            let summaryLabel: String

            switch range {
            case .daily:
                summaryValue = Int(total.rounded())
                summaryLabel = "Total"
            case .weekly, .monthly:
                summaryValue = Int(avg.rounded())
                summaryLabel = "Average"
            }

            DispatchQueue.main.async {
                self.bars = items
                self.headerDateText = header
                self.averageText = self.formatSteps(summaryValue)
                self.rangeText = summaryLabel
                self.yMax = yMax
            }
        }
    }

    // MARK: - Observers
    private func _installObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true

        // step-by-step inserts (either from Polar 360 or Apple Health mirror)
        NotificationCenter.default.addObserver(
            forName: .ctMetricUpdated,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            if let kind = note.userInfo?["kind"] as? String, kind == "steps" {
                StepEngine.invalidateCache()
                self.loadCurrentWindow()
            }
        }

        // bulk mirror finished
        NotificationCenter.default.addObserver(
            forName: .ctMetricsDidMirror,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            StepEngine.invalidateCache()
            self.loadCurrentWindow()
        }

        // app back to foreground → refresh window
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            StepEngine.invalidateCache()
            self.loadCurrentWindow()
        }
    }

    // MARK: - Windows / Bucketing
    private func window(for range: ChartTimeRange, center: Date) -> (Date, Date) {
        switch range {
        case .daily:
            let start = calendar.startOfDay(for: center)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        case .weekly:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: center))!
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            return (start, end)
        case .monthly:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: center))!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
        }
    }

    private func bucketStart(for date: Date, within domain: ClosedRange<Date>, range: ChartTimeRange) -> Date {
        switch range {
        case .daily:
            return calendar.dateInterval(of: .hour, for: date)?.start ?? date
        case .weekly:
            return calendar.startOfDay(for: date)
        case .monthly:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            return max(weekStart, domain.lowerBound)
        }
    }

    private func shift(center: Date, for range: ChartTimeRange, direction: Int) -> Date {
        switch range {
        case .daily:
            return calendar.date(byAdding: .day, value: direction, to: center)!
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: direction, to: center)!
        case .monthly:
            return calendar.date(byAdding: .month, value: direction, to: center)!
        }
    }

    private func periodAnchor(for range: ChartTimeRange, date: Date) -> Date {
        switch range {
        case .daily:
            return calendar.startOfDay(for: date)
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        case .monthly:
            return calendar.dateInterval(of: .month, for: date)?.start ?? date
        }
    }

    // MARK: - Labels
    private func headerTitle(range: ChartTimeRange, start: Date, end: Date) -> String {
        let df = DateFormatter()
        switch range {
        case .daily:
            df.dateFormat = "MMM d, yyyy"; return df.string(from: start)
        case .weekly:
            df.dateFormat = "MMM d"
            let s = df.string(from: start)
            let e = df.string(from: calendar.date(byAdding: .day, value: -1, to: end)!)
            return "\(s) - \(e) \(calendar.component(.year, from: start))"
        case .monthly:
            df.dateFormat = "MMMM yyyy"; return df.string(from: start)
        }
    }

    private func formatSteps(_ count: Int) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .decimal
        return nf.string(from: .init(value: count)) ?? "0"
    }
}
