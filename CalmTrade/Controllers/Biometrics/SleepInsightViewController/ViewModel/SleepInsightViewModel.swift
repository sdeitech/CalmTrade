//
//  SleepInsightViewModel.swift
//  CalmTrade
//

import Foundation
import SwiftUI
import UIKit

final class SleepInsightViewModel {

    enum ChartTimeRange: Int, CaseIterable {
        case daily = 0, weekly, monthly

        var title: String {
            switch self {
            case .daily:  return "Daily"
            case .weekly: return "Weekly"
            case .monthly:return "Monthly"
            }
        }
    }

    // MARK: - Bindings
    var onDataUpdate: ((_ uiData: SleepUIData, _ isPaginating: Bool) -> Void)?
    var onIsLoading: ((Bool) -> Void)?

    // MARK: - Private
    private let repo = SleepRepository.shared
    private var sleepSegments: [SleepSegment] = []

    private var currentlyDisplayedStartDate = Date()
    private var currentlyDisplayedEndDate   = Date()

    private var selectedRange: ChartTimeRange = .daily
    private var isLoadingData = false
    private var anchorDate: Date = Date()

    // MARK: - Public API

    func fetchInitialData(for range: ChartTimeRange) {
        selectedRange = range
        sleepSegments.removeAll()

        anchorDate = Date()
        let p = period(for: range, anchoredAt: anchorDate)

        currentlyDisplayedStartDate = p.start
        currentlyDisplayedEndDate   = p.end

        loadData(start: p.start, end: p.end, isPaginating: false)
    }

    func loadPreviousPeriod() {
        guard !isLoadingData else { return }

        anchorDate = previousAnchor(from: anchorDate, for: selectedRange)
        let p = period(for: selectedRange, anchoredAt: anchorDate)

        currentlyDisplayedStartDate = p.start
        currentlyDisplayedEndDate   = p.end

        loadData(start: p.start, end: p.end, isPaginating: true)
    }

    // MARK: - Unified Fetch (Repository only)
    func loadData(start: Date, end: Date, isPaginating: Bool) {
        guard !isLoadingData else { return }
        isLoadingData = true
        onIsLoading?(true)

        currentlyDisplayedStartDate = start
        currentlyDisplayedEndDate   = end

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            // Unified (ct360 > HK) from SleepRepository
            let segs = self.repo.unifiedSegments(from: start, to: end)

            DispatchQueue.main.async {
                self.processUnifiedSegments(segs, start: start, end: end, isPaginating: isPaginating)
            }
        }
    }

    // MARK: - Segment processing pipeline
    private func processUnifiedSegments(
        _ segs: [SleepSegment],
        start: Date,
        end: Date,
        isPaginating: Bool
    ) {
        // Coalesce stage segments
        var merged = Self.coalesce(segments: segs.sorted { $0.start < $1.start }, joinThreshold: 60)

        if isPaginating {
            sleepSegments.insert(contentsOf: merged, at: 0)
        } else {
            sleepSegments = merged
        }

        sleepSegments.sort { $0.start < $1.start }

        // Compute total union-asleep seconds
        let total = Self.totalAsleepUnionSeconds(from: sleepSegments)

        let ui = SleepUIData(
            timeAsleepAttributedText: formatTimeAsleep(total),
            sleepDate: formatSleepDate(start, end),
            sleepSegments: sleepSegments,
            chartStartDate: start,
            chartEndDate: end
        )

        onDataUpdate?(ui, isPaginating)
        isLoadingData = false
        onIsLoading?(false)
    }

    // MARK: - Segment Coalescing + Union-Asleep

    private static func coalesce(segments: [SleepSegment],
                                 joinThreshold: TimeInterval) -> [SleepSegment] {
        var out: [SleepSegment] = []

        for seg in segments {
            if var last = out.last,
               last.stage == seg.stage,
               seg.start.timeIntervalSince(last.end) <= joinThreshold {

                out.removeLast()
                out.append(
                    SleepSegment(
                        stage: last.stage,
                        start: last.start,
                        end: max(last.end, seg.end),
                        source: last.source
                    )
                )
            } else {
                out.append(seg)
            }
        }

        return out
    }

    private static func totalAsleepUnionSeconds(from segments: [SleepSegment]) -> TimeInterval {
        var intervals = segments
            .filter { $0.stage != .awake }
            .map { ($0.start, $0.end) }
            .sorted { $0.0 < $1.0 }

        var merged: [(Date, Date)] = []

        for (s, e) in intervals {
            guard s < e else { continue }
            if let last = merged.last, s <= last.1 {
                merged[merged.count - 1].1 = max(last.1, e)
            } else {
                merged.append((s, e))
            }
        }

        return merged.reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) }
    }

    // MARK: - Formatting

    private func formatSleepDate(_ start: Date, _ end: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let s = df.string(from: start)
        let e = df.string(from: end)
        return s == e ? s : "\(s) – \(e)"
    }

    private func formatTimeAsleep(_ i: TimeInterval) -> NSAttributedString {
        let hours = Int(i) / 3600
        let minutes = (Int(i) / 60) % 60

        let bold = UIFont.boldSystemFont(ofSize: 28)
        let reg  = UIFont.systemFont(ofSize: 16)

        let s = NSMutableAttributedString()
        s.append(NSAttributedString(string: "\(hours)", attributes: [.font: bold, .foregroundColor: UIColor.white]))
        s.append(NSAttributedString(string: " hr ",      attributes: [.font: reg,  .foregroundColor: UIColor.lightGray]))
        s.append(NSAttributedString(string: "\(minutes)",attributes: [.font: reg,  .foregroundColor: UIColor.white]))
        s.append(NSAttributedString(string: " min",      attributes: [.font: reg,  .foregroundColor: UIColor.lightGray]))

        return s
    }

    // MARK: - Paging Periods

    private func period(for range: ChartTimeRange, anchoredAt anchor: Date) -> Period {
        let cal = Calendar.current

        switch range {
        case .daily:
            let start = cal.startOfDay(for: anchor)
            let end   = cal.date(byAdding: .day, value: 1, to: start)!
            return Period(start: start, end: end)

        case .weekly:
            let start = cal.date(from:
                cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchor)
            )!
            let end = cal.date(byAdding: .day, value: 7, to: start)!
            return Period(start: start, end: end)

        case .monthly:
            let comps = cal.dateComponents([.year, .month], from: anchor)
            let start = cal.date(from: comps)!
            let end   = cal.date(byAdding: .month, value: 1, to: start)!
            return Period(start: start, end: end)
        }
    }

    private func previousAnchor(from anchor: Date, for range: ChartTimeRange) -> Date {
        let cal = Calendar.current
        switch range {
        case .daily:   return cal.date(byAdding: .day, value: -1, to: anchor)!
        case .weekly:  return cal.date(byAdding: .weekOfYear, value: -1, to: anchor)!
        case .monthly: return cal.date(byAdding: .month, value: -1, to: anchor)!
        }
    }
}

// MARK: - Period Struct
private struct Period {
    let start: Date
    let end: Date     // exclusive
}
