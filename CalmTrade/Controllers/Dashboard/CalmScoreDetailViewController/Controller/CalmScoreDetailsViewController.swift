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
    private enum ChartTransitionStyle: Equatable {
        case none
        case crossDissolve
        case slideFromLeft
        case slideFromRight
    }

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
    private var pendingTransitionStyle: ChartTransitionStyle = .none

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
    private var dayAnchorDate: Date = Date()
    private var weekAnchorDate: Date = Date()
    private var monthAnchorDate: Date = Date()
    private var yearAnchorDate: Date = Date()

    private let cal = Calendar.current

    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        configureSegmented()
        embedChart()
        installPagingGestures()
        configureCollection()
        bindViewModel()

        // Default to Hour tab and request minute-scale data (source scale for Hour)
        timeScaleSegmented.selectedSegmentIndex = 0
        resetAnchor(for: .H)
        viewModel.setScale(.minute, end: visibleWindowEnd(for: .H))
        viewModel.start()

        // Build initial caches for W/M/Y from the store so first swap is correct
        rebuildCachesFromStore(for: .W, anchor: weekAnchorDate)
        rebuildCachesFromStore(for: .M, anchor: monthAnchorDate)
        rebuildCachesFromStore(for: .Y, anchor: yearAnchorDate)
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
        let nextView = makeChartView()
        applyTransitionIfNeeded(on: chartHost.view)
        chartHost.rootView = nextView
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
            return AnyView(DayChartView(hourlyRanges: hourlyRangesToday, anchor: dayAnchorDate)
                .frame(maxWidth: .infinity, maxHeight: .infinity))
        case .W:
            return AnyView(WeekChartView(weekRanges, weekAnchor: weekAnchorDate)
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

    private func installPagingGestures() {
        let left = UISwipeGestureRecognizer(target: self, action: #selector(didSwipeLeft))
        left.direction = .left
        graphContainerView.addGestureRecognizer(left)

        let right = UISwipeGestureRecognizer(target: self, action: #selector(didSwipeRight))
        right.direction = .right
        graphContainerView.addGestureRecognizer(right)
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$graph
            .receive(on: RunLoop.main)
            .sink { [weak self] points in
                guard let self else { return }

                // For Day view: build 24 hourly slots from HOURLY points (VM emits .hour)
                let timed = points.map { TimedPoint(date: $0.date, value: max(0, min(100, $0.value))) }
                self.hourlyRangesToday = Self.makeDayRanges(from: timed, anchor: self.dayAnchorDate)

                // For W/M/Y we rebuild directly from the store (windowed & bucketed correctly)
                self.rebuildCachesFromStore(for: .W, anchor: self.weekAnchorDate)
                self.rebuildCachesFromStore(for: .M, anchor: self.monthAnchorDate)
                self.rebuildCachesFromStore(for: .Y, anchor: self.yearAnchorDate)

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
            hourlyRangesToday = Self.makeDayRanges(from: timed, anchor: dayAnchorDate)
        case .W:
            rebuildCachesFromStore(for: .W, anchor: weekAnchorDate)
        case .M:
            rebuildCachesFromStore(for: .M, anchor: monthAnchorDate)
        case .Y:
            rebuildCachesFromStore(for: .Y, anchor: yearAnchorDate)
        }
    }

    // MARK: - Store-backed cache builders for W / M / Y
    private func rebuildCachesFromStore(for tab: Tab, anchor: Date) {
        let store = CalmScoreStore.shared
        switch tab {
        case .W:
            let startOfWeek = cal.dateInterval(of: .weekOfYear, for: anchor)!.start
            let end = min(cal.date(byAdding: .day, value: 7, to: startOfWeek)!.addingTimeInterval(-1), Date())
            let aggs = store.fetchSeries(scale: .day, start: startOfWeek, end: end)
            let pts = aggs.map { TimedPoint(date: $0.bucketStart, value: max(0, min(100, $0.avg))) }
            weekRanges = Self.makeWeekRanges(from: pts, anchor: anchor)

        case .M:
            let startOfMonth = cal.dateInterval(of: .month, for: anchor)!.start
            let end = min(cal.date(byAdding: .month, value: 1, to: startOfMonth)!.addingTimeInterval(-1), Date())
            let aggs = store.fetchSeries(scale: .day, start: startOfMonth, end: end)
            let pts = aggs.map { TimedPoint(date: $0.bucketStart, value: max(0, min(100, $0.avg))) }
            monthDailyRanges = Self.makeMonthRanges(from: pts, anchor: anchor)

        case .Y:
            let startOfYear = cal.dateInterval(of: .year, for: anchor)!.start
            let end = min(cal.date(byAdding: .year, value: 1, to: startOfYear)!.addingTimeInterval(-1), Date())
            let aggs = store.fetchSeries(scale: .month, start: startOfYear, end: end)
            let pts = aggs.map { TimedPoint(date: $0.bucketStart, value: max(0, min(100, $0.avg))) }
            yearMonthlyRanges = Self.makeYearRanges(from: pts, anchor: anchor)

        default:
            break
        }
    }

    // MARK: - Actions

    @objc private func scaleChanged() {
        pendingTransitionStyle = .crossDissolve
        resetAnchor(for: currentTab)
        reloadVisibleTabData()
    }

    @objc private func didSwipeLeft() { // newer period
        guard canPageForward(for: currentTab) else {
            pendingTransitionStyle = .none
            return
        }
        shiftAnchor(for: currentTab, direction: 1)
        pendingTransitionStyle = .slideFromLeft
        reloadVisibleTabData()
    }

    @objc private func didSwipeRight() { // older period
        shiftAnchor(for: currentTab, direction: -1)
        pendingTransitionStyle = .slideFromRight
        reloadVisibleTabData()
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
        switch currentTab {
        case .H:
            let start = hourAnchorStart
            let end   = cal.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
            timeframeLabel.text = hourRangeText(start: start, end: end)

        case .D:
            timeframeLabel.text = dayText(for: dayAnchorDate)

        case .W:
            let startOfWeek = cal.dateInterval(of: .weekOfYear, for: weekAnchorDate)?.start ?? weekAnchorDate
            let endOfWeek = cal.date(byAdding: .day, value: 7, to: startOfWeek)?.addingTimeInterval(-1) ?? weekAnchorDate
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

    private func resetAnchor(for tab: Tab) {
        let now = Date()
        switch tab {
        case .H:
            hourAnchorStart = cal.dateInterval(of: .hour, for: now)?.start ?? now
        case .D:
            dayAnchorDate = now
        case .W:
            weekAnchorDate = now
        case .M:
            monthAnchorDate = now
        case .Y:
            yearAnchorDate = now
        }
    }

    private func shiftAnchor(for tab: Tab, direction: Int) {
        switch tab {
        case .H:
            hourAnchorStart = cal.date(byAdding: .hour, value: direction, to: hourAnchorStart) ?? hourAnchorStart
        case .D:
            dayAnchorDate = cal.date(byAdding: .day, value: direction, to: dayAnchorDate) ?? dayAnchorDate
        case .W:
            weekAnchorDate = cal.date(byAdding: .weekOfYear, value: direction, to: weekAnchorDate) ?? weekAnchorDate
        case .M:
            monthAnchorDate = cal.date(byAdding: .month, value: direction, to: monthAnchorDate) ?? monthAnchorDate
        case .Y:
            yearAnchorDate = cal.date(byAdding: .year, value: direction, to: yearAnchorDate) ?? yearAnchorDate
        }
    }

    private func visibleAnchor(for tab: Tab) -> Date {
        switch tab {
        case .H: return hourAnchorStart
        case .D: return dayAnchorDate
        case .W: return weekAnchorDate
        case .M: return monthAnchorDate
        case .Y: return yearAnchorDate
        }
    }

    private func periodAnchor(for tab: Tab, date: Date) -> Date {
        switch tab {
        case .H:
            return cal.dateInterval(of: .hour, for: date)?.start ?? date
        case .D:
            return cal.startOfDay(for: date)
        case .W:
            return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        case .M:
            return cal.dateInterval(of: .month, for: date)?.start ?? date
        case .Y:
            return cal.dateInterval(of: .year, for: date)?.start ?? date
        }
    }

    private func canPageForward(for tab: Tab) -> Bool {
        periodAnchor(for: tab, date: visibleAnchor(for: tab)) < periodAnchor(for: tab, date: Date())
    }

    private func visibleWindowEnd(for tab: Tab) -> Date {
        let now = Date()
        let start = periodAnchor(for: tab, date: visibleAnchor(for: tab))
        let end: Date
        switch tab {
        case .H:
            end = cal.date(byAdding: .hour, value: 1, to: start)?.addingTimeInterval(-1) ?? start
        case .D:
            end = cal.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? start
        case .W:
            end = cal.date(byAdding: .day, value: 7, to: start)?.addingTimeInterval(-1) ?? start
        case .M:
            end = cal.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? start
        case .Y:
            end = cal.date(byAdding: .year, value: 1, to: start)?.addingTimeInterval(-1) ?? start
        }
        return min(end, now)
    }

    private func reloadVisibleTabData() {
        let end = visibleWindowEnd(for: currentTab)
        switch currentTab {
        case .H:
            viewModel.setScale(.minute, end: end)
        case .D:
            viewModel.setScale(.hour, end: end)
        case .W:
            viewModel.setScale(.day, end: end)
            rebuildCachesFromStore(for: .W, anchor: weekAnchorDate)
            refreshChart()
        case .M:
            viewModel.setScale(.day, end: end)
            rebuildCachesFromStore(for: .M, anchor: monthAnchorDate)
            refreshChart()
        case .Y:
            viewModel.setScale(.month, end: end)
            rebuildCachesFromStore(for: .Y, anchor: yearAnchorDate)
            refreshChart()
        }
        updateTimeframeLabel()
    }

    private func applyTransitionIfNeeded(on view: UIView) {
        defer { pendingTransitionStyle = .none }
        switch pendingTransitionStyle {
        case .none:
            return
        case .crossDissolve:
            UIView.transition(with: view, duration: 0.22, options: [.transitionCrossDissolve, .allowAnimatedContent], animations: nil)
        case .slideFromLeft, .slideFromRight:
            let transition = CATransition()
            transition.type = .push
            transition.duration = 0.28
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            transition.subtype = pendingTransitionStyle == .slideFromLeft ? .fromRight : .fromLeft
            view.layer.add(transition, forKey: "CalmScoreChartPaging")
        }
    }
}
