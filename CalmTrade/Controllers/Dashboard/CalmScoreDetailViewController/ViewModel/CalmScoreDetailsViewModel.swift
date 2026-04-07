//
//  CalmScoreDetailsViewModel.swift
//  CalmTrade
//

import Foundation
import Combine
import UIKit

@MainActor
final class CalmScoreDetailsViewModel: ObservableObject {

    // MARK: - Inputs
    @Published private(set) var scale: CalmTimeScale = .minute

    // MARK: - Outputs (common)
    @Published private(set) var graph: [CalmPoint] = []
    @Published private(set) var liveScoreText: String = "--"
    @Published private(set) var latestScoreText: String = "--"
    @Published private(set) var lastUpdatedText: String = "--"
    @Published private(set) var history: [CalmHistoryItem] = []
    @Published private(set) var windowEnd: Date = Date()

    // MARK: - Hour (3-minute buckets → 20 bars)
    /// Per-bucket min…max for the current hour. `nil` = no data for that bucket (future or missing).
    @Published private(set) var hourBucketRanges: [ClosedRange<Double>?] = []
    /// Start of the hour window (anchor for labels).
    @Published private(set) var hourAnchorStart: Date = Date()
    /// How many leading buckets should render (trailing are empty/future).
    @Published private(set) var hourFilledCount: Int = 0
    /// Bucket width in minutes (default 3 → 20 bars/hour, 5 per quarter-hour).
    @Published private(set) var hourBucketMinutes: Int = 3

    // MARK: - Private
    private var hubListenerId: UUID?
    private let reloadSubject = PassthroughSubject<Date, Never>()
    private let historySubject = PassthroughSubject<Date, Never>()
    private var cancellables = Set<AnyCancellable>()

    // Track async work so we can cancel at stop/deinit
    private var reloadTask: Task<Void, Never>?
    private var historyTask: Task<Void, Never>?

    private var didStart = false
    
    // Observe user switch and reload CalmScore data
    init() {
        NotificationCenter.default.addObserver(
            forName: .userAccountDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.stop()            // cancel old listeners and tasks
            self.didStart = false  // reset flag so start() can re-register
            self.start()           // rebuild graph + history for new user
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard !didStart else { return }
        didStart = true

        // Graph coalesce: once per minute boundary (prevents churn)
        reloadSubject
            .map { Calendar.current.date(bySetting: .second, value: 0, of: $0) ?? $0 }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reloadGraph() }
            .store(in: &cancellables)

        // History coalesce: also on minute boundary
        historySubject
            .map { Calendar.current.date(bySetting: .second, value: 0, of: $0) ?? $0 }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reloadHistory() }
            .store(in: &cancellables)

        // Live hub subscription — strictly weak to avoid retain cycles
        hubListenerId = CalmScoreHub.shared.addListener { [weak self] _, _, props in
            guard let s = self else { return }
            Task { @MainActor [weak s] in
                s?.updateLive(score: Double(props.score), date: props.lastUpdate)
            }
            s.reloadSubject.send(props.lastUpdate)
            s.historySubject.send(props.lastUpdate)
        }

        // Initial loads
        reloadGraph()
        reloadHistory()
    }

    /// Must be callable safely from `deinit` without hopping actors.
    func stop() {
        reloadTask?.cancel()
        historyTask?.cancel()
        if let id = hubListenerId { CalmScoreHub.shared.removeListener(id) }
        cancellables.removeAll()
    }

    // MARK: - Public

    func setScale(_ new: CalmTimeScale, end: Date = Date()) {
        scale = new
        windowEnd = end
        reloadGraph(end: end)
    }

    /// Change the hour bucket size (must divide 60). 3 → 20 bars; 6 → 10 bars; etc.
    func setHourBucketMinutes(_ minutes: Int) {
        guard minutes > 0, 60 % minutes == 0 else { return }
        hourBucketMinutes = minutes
        if scale == .minute { reloadGraph() }
    }

    /// Rebuild the visible graph for the current `scale`.
    func reloadGraph(end: Date? = nil) {
        // Snapshot on main actor
        let requestedScale = self.scale
        let bucketMinutes  = self.hourBucketMinutes
        let store = CalmScoreStore.shared
        let requestedEnd = end ?? self.windowEnd
        self.windowEnd = requestedEnd

        // Cancel any in-flight reload
        reloadTask?.cancel()
        reloadTask = Task.detached(priority: .userInitiated) { [requestedScale, bucketMinutes, requestedEnd] in
            if Task.isCancelled { return }

            if requestedScale == .minute {
                // Hour view: N-minute buckets with future buckets empty
                let hour = store.fetchHourBucketedRanges(end: requestedEnd, bucketMinutes: bucketMinutes)

                // ⬇️ was unbounded; now restrict to [startOfHour, end]
                let latestAggs = store.fetchSeries(
                    scale: .minute,
                    start: hour.startOfHour,
                    end: requestedEnd
                )

                if Task.isCancelled { return }

                let pts = latestAggs.map { CalmPoint(date: $0.bucketStart, value: $0.avg) }
                let latest = latestAggs.last  // guaranteed to be within the hour

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    guard requestedScale == self.scale else { return }
                    self.hourBucketRanges = hour.ranges
                    self.hourAnchorStart  = hour.startOfHour
                    self.hourFilledCount  = hour.filledCount
                    self.graph = pts
                    if let latest {
                        self.latestScoreText = "\(Int(round(latest.avg)))"
//                        self.updateLastUpdated(latest.bucketStart)
                    }
                }
                return
            }

            // ===== NEW: Calendar-anchored windows for D / W / M / Y =====
            let cal = Calendar.current
            let start: Date
            switch requestedScale {
            case .day:
                start = cal.startOfDay(for: requestedEnd)
            case .week:
                start = cal.dateInterval(of: .weekOfYear, for: requestedEnd)!.start
            case .month:
                start = cal.dateInterval(of: .month, for: requestedEnd)!.start
            case .year:
                start = cal.dateInterval(of: .year, for: requestedEnd)!.start
            default:
                // Fallback to day start (shouldn’t be hit, but keeps us safe)
                start = cal.startOfDay(for: requestedEnd)
            }

            // Pull only aggregates inside [start, end]
            let aggs = store.fetchSeries(scale: requestedScale, start: start, end: requestedEnd)
            if Task.isCancelled { return }

            let pts   = aggs.map { CalmPoint(date: $0.bucketStart, value: $0.avg) }
            let latest = aggs.last

            await MainActor.run { [weak self] in
                guard let self else { return }
                guard requestedScale == self.scale else { return }
                self.graph = pts
                if let latest {
                    self.latestScoreText = "\(Int(round(latest.avg)))"
//                    self.updateLastUpdated(latest.bucketStart)
                }
            }
        }
    }


    func reloadHistory(limit: Int = 60) {
        let store = CalmScoreStore.shared
        historyTask?.cancel()
        historyTask = Task.detached(priority: .utility) {
            if Task.isCancelled { return }
            let rows = store.fetchDailyAverages(limit: limit)
            if Task.isCancelled { return }
            let items = rows.map { CalmHistoryItem(day: $0.bucketStart, average: $0.avg) }
            await MainActor.run { [weak self] in self?.history = items }
        }
    }

    // MARK: - Helpers

    private func updateLive(score: Double, date: Date) {
        let new = "\(Int(round(score)))"
        if new != liveScoreText { liveScoreText = new }
        updateLastUpdated(date)
    }

    private func updateLastUpdated(_ date: Date) {
        let df = DateFormatter(); df.dateFormat = "h:mm a"
        let newText = df.string(from: date)
        if newText != lastUpdatedText { lastUpdatedText = newText }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .userAccountDidChange, object: nil)
    }
}
