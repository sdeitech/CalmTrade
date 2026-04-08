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
    private var currentSleepSegments: [SleepSegment] = []

    private var currentlyDisplayedStartDate = Date()
    private var currentlyDisplayedEndDate   = Date()

    private var selectedRange: ChartTimeRange = .daily
    private var isLoadingData = false
    private var anchorDate: Date = Date()

    // MARK: - Public API

    func fetchInitialData(for range: ChartTimeRange) {
        selectedRange = range
        currentSleepSegments.removeAll()

        anchorDate = Date()
        let p = period(for: range, anchoredAt: anchorDate)

        currentlyDisplayedStartDate = p.start
        currentlyDisplayedEndDate   = p.end

        loadData(start: p.start, end: p.end, isPaginating: false)
    }

    @discardableResult
    func loadPreviousPeriod() -> Bool {
        guard !isLoadingData else { return false }

        anchorDate = previousAnchor(from: anchorDate, for: selectedRange)
        let p = period(for: selectedRange, anchoredAt: anchorDate)

        currentlyDisplayedStartDate = p.start
        currentlyDisplayedEndDate   = p.end

        loadData(start: p.start, end: p.end, isPaginating: true)
        return true
    }

    @discardableResult
    func loadNextPeriod() -> Bool {
        guard !isLoadingData else { return false }

        let shiftedAnchor = nextAnchor(from: anchorDate, for: selectedRange)
        let nextPeriod = period(for: selectedRange, anchoredAt: shiftedAnchor)
        let currentPeriod = period(for: selectedRange, anchoredAt: Date())

        guard nextPeriod.start < currentPeriod.end else { return false }

        anchorDate = shiftedAnchor
        currentlyDisplayedStartDate = nextPeriod.start
        currentlyDisplayedEndDate = nextPeriod.end

        loadData(start: nextPeriod.start, end: nextPeriod.end, isPaginating: true)
        return true
    }

    // MARK: - Unified Fetch (Repository only)
    func loadData(start: Date, end: Date, isPaginating: Bool) {
        let fetchWindow = resolveFetchWindow(start: start, end: end, for: selectedRange)

        print("=== SleepInsight \(selectedRange.title) Fetch ===")
        print("Source: SleepRepository.shared.unifiedSegments(from:to:)")
        print("Window: \(fetchWindow.start) -> \(fetchWindow.end)")
        print("========================================")

        guard !isLoadingData else { return }
        isLoadingData = true
        onIsLoading?(true)

        currentlyDisplayedStartDate = fetchWindow.start
        currentlyDisplayedEndDate   = fetchWindow.end

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            // Unified (ct360 > HK) from SleepRepository
            let segs = self.repo.unifiedSegments(from: fetchWindow.start, to: fetchWindow.end)

            DispatchQueue.main.async {
                self.processUnifiedSegments(
                    segs,
                    start: fetchWindow.start,
                    end: fetchWindow.end,
                    isPaginating: isPaginating
                )
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
        let sourceCounts = Dictionary(grouping: segs, by: \.source).mapValues(\.count)
        let periodInBedSeconds = Self.totalInBedSeconds(from: segs)
        let periodAsleepSeconds = Self.totalAsleepUnionSeconds(from: segs)

        print("=== SleepInsight \(selectedRange.title) Data ===")
        print("Fetched Segments: \(segs.count)")
        print("Source Breakdown: \(sourceCounts)")
        print("Period Total In-Bed: \(Self.formatHhMm(seconds: periodInBedSeconds))")
        print("Period Total Asleep: \(Self.formatHhMm(seconds: periodAsleepSeconds))")
        print("======================================")

        currentSleepSegments = Self.coalesce(
            segments: segs.sorted { $0.start < $1.start },
            joinThreshold: 60
        ).sorted { $0.start < $1.start }

        let total = Self.totalAsleepUnionSeconds(from: currentSleepSegments)
        let sleepDateText = currentDateText(for: currentSleepSegments, start: start, end: end)

        print("Displayed Total (period asleep total): \(Self.formatHhMm(seconds: total))")
        print("Displayed Date Window: \(sleepDateText)")
        print("Displayed Segment Count: \(currentSleepSegments.count)")
        print("======================================")

        let totals = Self.stageTotals(from: currentSleepSegments)

        let ui = SleepUIData(
            timeAsleepAttributedText: formatTimeAsleep(total),
            sleepDate: sleepDateText,
            sleepSegments: currentSleepSegments,
            chartStartDate: start,
            chartEndDate: end,
            awakeSeconds: totals.awake,
            remSeconds: totals.rem,
            coreSeconds: totals.core,
            deepSeconds: totals.deep
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

    private static func totalInBedSeconds(from segments: [SleepSegment]) -> TimeInterval {
        segments.reduce(0.0) { acc, seg in
            acc + max(0.0, seg.end.timeIntervalSince(seg.start))
        }
    }

    // MARK: - Formatting

    private func formatSleepDate(_ start: Date, _ end: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let s = df.string(from: start)
        let e = df.string(from: end)
        return s == e ? s : "\(s) - \(e)"
    }

    private func formatSingleSleepDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }

    private func currentDateText(for segments: [SleepSegment], start: Date, end: Date) -> String {
        if selectedRange == .daily,
           let sessionEnd = segments.map(\.end).max() {
            return formatSingleSleepDate(sessionEnd)
        }

        return formatSleepDate(start, end.addingTimeInterval(-1))
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

    private static func formatHhMm(seconds: TimeInterval) -> String {
        let totalMinutes = Int((seconds / 60.0).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h)h \(m)m"
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
            let start = startOfWeekSunday(for: anchor, calendar: cal)
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
        case .weekly:  return cal.date(byAdding: .day, value: -7, to: anchor)!
        case .monthly: return cal.date(byAdding: .month, value: -1, to: anchor)!
        }
    }

    private func nextAnchor(from anchor: Date, for range: ChartTimeRange) -> Date {
        let cal = Calendar.current
        switch range {
        case .daily:   return cal.date(byAdding: .day, value: 1, to: anchor)!
        case .weekly:  return cal.date(byAdding: .day, value: 7, to: anchor)!
        case .monthly: return cal.date(byAdding: .month, value: 1, to: anchor)!
        }
    }

    private func resolveFetchWindow(start: Date, end: Date, for range: ChartTimeRange) -> (start: Date, end: Date) {
        guard range == .daily else { return (start, end) }

        let lookbackStart = end.addingTimeInterval(-72 * 3600)
        let sessions = repo.unifiedSessions(from: lookbackStart, to: end)
        guard let latest = sessions.last else { return (start, end) }
        return (latest.sessionStart, latest.sessionEnd)
    }

    private func startOfWeekSunday(for date: Date, calendar: Calendar) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: dayStart) // Sunday = 1
        let daysFromSunday = weekday - 1
        return calendar.date(byAdding: .day, value: -daysFromSunday, to: dayStart) ?? dayStart
    }
    
    private static func stageTotals(from segments: [SleepSegment]) -> (
        awake: TimeInterval,
        rem: TimeInterval,
        core: TimeInterval,
        deep: TimeInterval
    ) {
        var awake: TimeInterval = 0
        var rem: TimeInterval = 0
        var core: TimeInterval = 0
        var deep: TimeInterval = 0

        for seg in segments {
            let duration = max(0, seg.end.timeIntervalSince(seg.start))

            switch seg.stage {
            case .awake: awake += duration
            case .rem:   rem   += duration
            case .core:  core  += duration
            case .deep:  deep  += duration
            }
        }

        return (awake, rem, core, deep)
    }
    
    func formatStageTime(_ seconds: TimeInterval) -> NSAttributedString {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) / 60) % 60

        let big = UIFont(name: "HelveticaNeue-Bold", size: 30)//UIFont.boldSystemFont(ofSize: 30)
        let small = UIFont(name: "HelveticaNeue-Bold", size: 16)

        let s = NSMutableAttributedString()

        s.append(NSAttributedString(
            string: "\(hours)",
            attributes: [.font: big, .foregroundColor: UIColor.white]
        ))

        s.append(NSAttributedString(
            string: " hr ",
            attributes: [.font: small, .foregroundColor: UIColor.white]
        ))

        s.append(NSAttributedString(
            string: "\(minutes)",
            attributes: [.font: big, .foregroundColor: UIColor.white]
        ))

        s.append(NSAttributedString(
            string: " min",
            attributes: [.font: small, .foregroundColor: UIColor.white]
        ))

        return s
    }
}

// MARK: - Period Struct
private struct Period {
    let start: Date
    let end: Date     // exclusive
}
