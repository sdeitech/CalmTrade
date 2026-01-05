//
//  CalmScoreDetailsViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 11/09/25.
//

import UIKit
import Combine
import SwiftUI

final class CalmScoreDetailsViewController: UIViewController, UICollectionViewDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var graphContainerView: UIView!
    @IBOutlet weak var liveCalmScoreLabel: UILabel!
    @IBOutlet weak var lastUpdatedTimeLabel: UILabel!
    @IBOutlet weak var latestCalmScoreLabel: UILabel!
    @IBOutlet weak var timeScaleSegmented: UISegmentedControl!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewHeightCnst: NSLayoutConstraint!
    @IBOutlet weak var timeframeLabel: UILabel!

    // MARK: - Private
    private let viewModel = CalmScoreDetailsViewModel()
    private var cancellables = Set<AnyCancellable>()

    // Single SwiftUI host (we swap its rootView to whatever chart is needed)
    private var chartHost: UIHostingController<AnyView>!

    // History datasource
    private var dataSource: UICollectionViewDiffableDataSource<Int, CalmHistoryItem>!
    private var historyItems: [CalmHistoryItem] = []

    // Cached ranges per timeframe
    // HOUR (3-minute buckets → 20 slots; nil = no data)
    private var hourRanges3m: [ClosedRange<Double>?] = []
    private var hourFilledCount: Int = 0
    private var hourBucketMinutes: Int = 3

    // Non-hour caches
    private var hourlyRangesToday: [ClosedRange<Double>] = []   // Day (24)
    private var weekRanges: [ClosedRange<Double>] = []          // Week (7)
    private var monthDailyRanges: [ClosedRange<Double>] = []    // Month (28–31)
    private var yearMonthlyRanges: [ClosedRange<Double>] = []   // Year (12)

    // Anchors for label generation
    private var hourAnchorStart: Date = Calendar.current.dateInterval(of: .hour, for: Date())?.start ?? Date()
    private var monthAnchorDate: Date = Date()
    private var yearAnchorDate: Date = Date()

    private let cal = Calendar.current

    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        configureSegmented()
        embedChart()
        configureCollection()
        bindViewModel()

        // Default to Hour tab and request minute-scale data (source scale for Hour)
        timeScaleSegmented.selectedSegmentIndex = 0
        viewModel.setScale(.minute)
        viewModel.start()

        // Build initial caches for W/M/Y from the store so first swap is correct
        rebuildCachesFromStore(for: .W)
        rebuildCachesFromStore(for: .M)
        rebuildCachesFromStore(for: .Y)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCollectionHeightForTwoRows()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        presentCalmScoreLog()
    }

    // MARK: - Segmented control

    private func configureSegmented() {
        // Order: H, D, W, M, Y
        timeScaleSegmented.removeAllSegments()
        ["H","D","W","M","Y"].enumerated().forEach { i, t in
            timeScaleSegmented.insertSegment(withTitle: t, at: i, animated: false)
        }
        timeScaleSegmented.addTarget(self, action: #selector(scaleChanged), for: .valueChanged)
    }

    private enum Tab { case H, D, W, M, Y }

    private var currentTab: Tab {
        switch timeScaleSegmented.selectedSegmentIndex {
        case 0: return .H
        case 1: return .D
        case 2: return .W
        case 3: return .M
        default: return .Y
        }
    }

    // MARK: - Chart hosting

    private func embedChart() {
        let host = UIHostingController(rootView: AnyView(EmptyView()))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        graphContainerView.addSubview(host.view)
        graphContainerView.backgroundColor = .black
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: graphContainerView.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: graphContainerView.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: graphContainerView.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: graphContainerView.bottomAnchor),
        ])
        host.didMove(toParent: self)
        chartHost = host
        chartHost.view.backgroundColor = .black

        // initial render
        refreshChart()
        updateTimeframeLabel()
    }

    private func refreshChart() {
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            chartHost.rootView = makeChartView()
        }
    }

    private func makeChartView() -> AnyView {
        switch currentTab {
        case .H:
            return AnyView(
                HourChartView(
                    ranges: hourRanges3m,
                    startOfHour: hourAnchorStart,
                    bucketMinutes: hourBucketMinutes,
                    filledCount: hourFilledCount
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        case .D:
            return AnyView(DayChartView(hourlyRanges: hourlyRangesToday)
                .frame(maxWidth: .infinity, maxHeight: .infinity))
        case .W:
            return AnyView(WeekChartView(weekRanges)
                .frame(maxWidth: .infinity, maxHeight: .infinity))
        case .M:
            return AnyView(MonthChartView(dailyRanges: monthDailyRanges, monthAnchorDate: monthAnchorDate)
                .frame(maxWidth: .infinity, maxHeight: .infinity))
        case .Y:
            return AnyView(YearChartView(yearMonthlyRanges)
                .frame(maxWidth: .infinity, maxHeight: .infinity))
        }
    }

    // MARK: - Collection

    private func configureCollection() {
        let layout = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout) ?? {
            let l = UICollectionViewFlowLayout()
            collectionView.setCollectionViewLayout(l, animated: false)
            return l
        }()

        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        layout.estimatedItemSize = .zero

        collectionView.register(CalmGaugeCell.self, forCellWithReuseIdentifier: CalmGaugeCell.reuseId)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = true
        collectionView.isPagingEnabled = true
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$graph
            .receive(on: RunLoop.main)
            .sink { [weak self] points in
                guard let self else { return }

                // Update anchors for labels if we have at least one point
                if let lastDate = points.last?.date {
                    self.hourAnchorStart = Calendar.current
                        .dateInterval(of: .hour, for: lastDate)?.start ?? self.hourAnchorStart
                    self.monthAnchorDate = lastDate
                    self.yearAnchorDate = lastDate
                }

                // For Day view: build 24 hourly slots from HOURLY points (VM emits .hour)
                let timed = points.map { TimedPoint(date: $0.date, value: max(0, min(100, $0.value))) }
                self.hourlyRangesToday = Self.makeDayRanges(from: timed, anchor: Date())

                // For W/M/Y we rebuild directly from the store (windowed & bucketed correctly)
                self.rebuildCachesFromStore(for: .W)
                self.rebuildCachesFromStore(for: .M)
                self.rebuildCachesFromStore(for: .Y)

                self.refreshChart()
                self.updateTimeframeLabel()
            }
            .store(in: &cancellables)

        // ---- Hour tab (3-minute buckets → 20 bars) ----
        viewModel.$hourBucketRanges
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] ranges in
                guard let self else { return }
                self.hourRanges3m = ranges
                if self.currentTab == .H { self.refreshChart() }
            }
            .store(in: &cancellables)

        viewModel.$hourAnchorStart
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] anchor in
                guard let self else { return }
                self.hourAnchorStart = anchor
                if self.currentTab == .H {
                    self.refreshChart()
                    self.updateTimeframeLabel()
                }
            }
            .store(in: &cancellables)

        viewModel.$hourFilledCount
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] filled in
                guard let self else { return }
                self.hourFilledCount = filled
                if self.currentTab == .H { self.refreshChart() }
            }
            .store(in: &cancellables)

        viewModel.$hourBucketMinutes
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] mins in
                guard let self else { return }
                self.hourBucketMinutes = mins
                if self.currentTab == .H { self.refreshChart() }
            }
            .store(in: &cancellables)

        // ---- Labels ----
        viewModel.$liveScoreText
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.liveCalmScoreLabel.text = $0 }
            .store(in: &cancellables)

        viewModel.$lastUpdatedText
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                guard let self else { return }
                UIView.performWithoutAnimation {
                    self.lastUpdatedTimeLabel.text = text
                    self.lastUpdatedTimeLabel.layoutIfNeeded()
                }
            }
            .store(in: &cancellables)

        viewModel.$latestScoreText
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.latestCalmScoreLabel.text = $0 }
            .store(in: &cancellables)

        // ---- History tiles ----
        viewModel.$history
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                guard let self else { return }
                self.historyItems = items
                self.collectionView.reloadData()
                self.collectionView.layoutIfNeeded()
                self.updateCollectionHeightForTwoRows()
            }
            .store(in: &cancellables)
    }

    // Recompute visible cache from current VM graph for D only (W/M/Y use store)
    private func recomputeCachesFromCurrentGraph() {
        let timed = viewModel.graph.map { TimedPoint(date: $0.date, value: max(0, min(100, $0.value))) }
        switch currentTab {
        case .H:
            break
        case .D:
            hourlyRangesToday = Self.makeDayRanges(from: timed, anchor: Date())
        case .W:
            rebuildCachesFromStore(for: .W)
        case .M:
            rebuildCachesFromStore(for: .M)
        case .Y:
            rebuildCachesFromStore(for: .Y)
        }
    }

    // MARK: - Store-backed cache builders for W / M / Y
    private func rebuildCachesFromStore(for tab: Tab) {
        let store = CalmScoreStore.shared
        let now = Date()
        switch tab {
        case .W:
            // Daily buckets from start-of-week…now
            let startOfWeek = cal.dateInterval(of: .weekOfYear, for: now)!.start
            let aggs = store.fetchSeries(scale: .day, start: startOfWeek, end: now)
            let pts = aggs.map { TimedPoint(date: $0.bucketStart, value: max(0, min(100, $0.avg))) }
            weekRanges = Self.makeWeekRanges(from: pts, anchor: now)

        case .M:
            // Daily buckets from first-of-month…now
            let startOfMonth = cal.dateInterval(of: .month, for: now)!.start
            let aggs = store.fetchSeries(scale: .day, start: startOfMonth, end: now)
            let pts = aggs.map { TimedPoint(date: $0.bucketStart, value: max(0, min(100, $0.avg))) }
            monthAnchorDate = now
            monthDailyRanges = Self.makeMonthRanges(from: pts, anchor: monthAnchorDate)

        case .Y:
            // Monthly buckets from Jan 1…now
            let startOfYear = cal.dateInterval(of: .year, for: now)!.start
            let aggs = store.fetchSeries(scale: .month, start: startOfYear, end: now)
            let pts = aggs.map { TimedPoint(date: $0.bucketStart, value: max(0, min(100, $0.avg))) }
            yearAnchorDate = now
            yearMonthlyRanges = Self.makeYearRanges(from: pts, anchor: yearAnchorDate)

        default:
            break
        }
    }

    // MARK: - Actions

    @objc private func scaleChanged() {
        // 1) Instant rebuild from what we already have
        recomputeCachesFromCurrentGraph()
        refreshChart()

        // 2) Ask VM for the correct SOURCE scale for this tab
        switch currentTab {
        case .H: viewModel.setScale(.minute)  // hour tab: minute buckets
        case .D: viewModel.setScale(.hour)    // day tab: hourly buckets
        case .W: viewModel.setScale(.day)     // week tab: daily buckets (we fetch window via store)
        case .M: viewModel.setScale(.day)     // month tab: daily buckets
        case .Y: viewModel.setScale(.month)   // year tab: monthly buckets
        }

        // 3) Make sure W/M/Y caches are up-to-date for the newly selected tab
        switch currentTab {
        case .W, .M, .Y:
            rebuildCachesFromStore(for: currentTab)
        default:
            break
        }

        updateTimeframeLabel()
    }

    @IBAction func btnBackClk(_ sender: UIButton) {
        navigationController?.popViewController()
    }

    private func presentCalmScoreLog() {
        let log = CalmScoreLogView(limit: nil, newestFirst: true)
        let host = UIHostingController(rootView: log)
        host.modalPresentationStyle = .formSheet
        present(host, animated: true, completion: nil)
    }
}

// MARK: - Range-building helpers (TIMESTAMP-AWARE)
private extension CalmScoreDetailsViewController {

    struct TimedPoint { let date: Date; let value: Double }

    static func thinRange(_ v: Double, pad: Double = 1.0) -> ClosedRange<Double> {
        let lo = max(0, min(100, v - pad))
        let hi = max(0, min(100, v + pad))
        return min(lo, hi)...max(lo, hi)
    }

    @inline(__always)
    static func add(_ v: Double, into range: inout ClosedRange<Double>) {
        range = min(range.lowerBound, v)...max(range.upperBound, v)
    }

    // ---- DAY: 24 hourly slots anchored to startOfDay(of: anchor) ----
    static func makeDayRanges(from points: [TimedPoint], anchor: Date) -> [ClosedRange<Double>] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: anchor)
        let end   = cal.date(byAdding: .day, value: 1, to: start)!

        var out = Array(repeating: 0.0...0.0, count: 24)

        for p in points where p.date >= start && p.date < end {
            let hour = cal.component(.hour, from: p.date) // 0…23
            let v = max(0, min(100, p.value))
            if out[hour].lowerBound == 0 && out[hour].upperBound == 0 {
                out[hour] = thinRange(v)
            } else {
                add(v, into: &out[hour])
            }
        }
        return out
    }

    // ---- WEEK: 7 day slots (Sun→Sat) anchored to week(of: anchor) ----
    static func makeWeekRanges(from points: [TimedPoint], anchor: Date) -> [ClosedRange<Double>] {
        let cal = Calendar.current
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: anchor)?.start ?? cal.startOfDay(for: anchor)
        let endOfWeek   = cal.date(byAdding: .day, value: 7, to: startOfWeek)!

        var out = Array(repeating: 0.0...0.0, count: 7)

        for p in points where p.date >= startOfWeek && p.date < endOfWeek {
            let dayIdx = cal.dateComponents([.day], from: startOfWeek, to: p.date).day ?? 0 // 0…6
            let v = max(0, min(100, p.value))
            if out[dayIdx].lowerBound == 0 && out[dayIdx].upperBound == 0 {
                out[dayIdx] = thinRange(v)
            } else {
                add(v, into: &out[dayIdx])
            }
        }
        return out
    }

    // ---- MONTH: N day slots anchored to 1st of that month ----
    static func makeMonthRanges(from points: [TimedPoint], anchor: Date) -> [ClosedRange<Double>] {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: anchor)) ?? cal.startOfDay(for: anchor)
        let end   = cal.date(byAdding: .month, value: 1, to: start)!
        let days  = cal.range(of: .day, in: .month, for: start)!.count

        var out = Array(repeating: 0.0...0.0, count: days)

        for p in points where p.date >= start && p.date < end {
            let dayIdx = cal.component(.day, from: p.date) - 1 // 0-based
            let v = max(0, min(100, p.value))
            if out[dayIdx].lowerBound == 0 && out[dayIdx].upperBound == 0 {
                out[dayIdx] = thinRange(v)
            } else {
                add(v, into: &out[dayIdx])
            }
        }
        return out
    }

    // ---- YEAR: 12 month slots anchored to Jan 1 of that year ----
    static func makeYearRanges(from points: [TimedPoint], anchor: Date) -> [ClosedRange<Double>] {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year], from: anchor)) ?? cal.startOfDay(for: anchor)
        let end   = cal.date(byAdding: .year, value: 1, to: start)!

        var out = Array(repeating: 0.0...0.0, count: 12)

        for p in points where p.date >= start && p.date < end {
            let mIdx = cal.component(.month, from: p.date) - 1 // 0…11
            let v = max(0, min(100, p.value))
            if out[mIdx].lowerBound == 0 && out[mIdx].upperBound == 0 {
                out[mIdx] = thinRange(v)
            } else {
                add(v, into: &out[mIdx])
            }
        }
        return out
    }
}

extension CalmScoreDetailsViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        historyItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CalmGaugeCell.reuseId, for: indexPath) as! CalmGaugeCell
        let item = historyItems[indexPath.row]
        cell.configure(item)
        cell.backgroundColor = .clear
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = 2
        guard let layout = collectionViewLayout as? UICollectionViewFlowLayout else {
            return CGSize(width: 120, height: 120)
        }

        let insets = layout.sectionInset
        let spacing = layout.minimumInteritemSpacing
        let availableW = collectionView.bounds.width - insets.left - insets.right
        let totalSpacing = spacing * (columns - 1)
        let side = floor((availableW - totalSpacing) / columns)   // square

        return CGSize(width: side, height: side)
    }

    private func updateCollectionHeightForTwoRows() {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let rows: CGFloat = 2
        let columns: CGFloat = 2

        let availableW = collectionView.bounds.width - layout.sectionInset.left - layout.sectionInset.right
        let totalColSpacing = layout.minimumInteritemSpacing * (columns - 1)
        let side = floor((availableW - totalColSpacing) / columns)

        let totalRowSpacing = layout.minimumLineSpacing * (rows - 1)
        let height = layout.sectionInset.top + rows * side + totalRowSpacing + layout.sectionInset.bottom

        collectionViewHeightCnst.constant = height
    }
}

extension CalmScoreDetailsViewController {
    private func updateTimeframeLabel() {
        let now = Date()
        switch currentTab {
        case .H:
            let start = hourAnchorStart
            let end   = cal.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
            timeframeLabel.text = hourRangeText(start: start, end: end)

        case .D:
            let day = viewModel.graph.last?.date ?? now
            timeframeLabel.text = dayText(for: day)

        case .W:
            let startOfWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = cal.date(byAdding: .day, value: 7, to: startOfWeek)?.addingTimeInterval(-1) ?? now
            timeframeLabel.text = weekRangeText(start: startOfWeek, end: endOfWeek)

        case .M:
            let startOfMonth = cal.dateInterval(of: .month, for: monthAnchorDate)?.start ?? monthAnchorDate
            timeframeLabel.text = monthText(for: startOfMonth)

        case .Y:
            let startOfYear = cal.dateInterval(of: .year, for: yearAnchorDate)?.start ?? yearAnchorDate
            timeframeLabel.text = yearText(for: startOfYear)
        }
    }

    private func hourRangeText(start: Date, end: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "h a"
        let s = df.string(from: start)
        let e = df.string(from: end)
        let ampm = DateFormatter(); ampm.dateFormat = "a"
        if ampm.string(from: start) == ampm.string(from: end) {
            let hourOnly = DateFormatter(); hourOnly.dateFormat = "h"
            return "\(hourOnly.string(from: start))–\(hourOnly.string(from: end)) \(ampm.string(from: end))"
        } else {
            return "\(s)–\(e)"
        }
    }

    private func dayText(for date: Date) -> String {
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let df = DateFormatter(); df.dateFormat = "EEE, MMM d"
        return df.string(from: date)
    }

    private func weekRangeText(start: Date, end: Date) -> String {
        let d1 = DateFormatter(); d1.dateFormat = "MMM d"
        let d2SameMonth = DateFormatter(); d2SameMonth.dateFormat = "d, yyyy"
        let d2CrossMonth = DateFormatter(); d2CrossMonth.dateFormat = "MMM d, yyyy"

        if cal.component(.month, from: start) == cal.component(.month, from: end) {
            return "\(d1.string(from: start))–\(d2SameMonth.string(from: end))"
        } else {
            return "\(d1.string(from: start)) – \(d2CrossMonth.string(from: end))"
        }
    }

    private func monthText(for startOfMonth: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "MMMM yyyy"
        return df.string(from: startOfMonth)
    }

    private func yearText(for startOfYear: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy"
        return df.string(from: startOfYear)
    }
}
