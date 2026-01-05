//
//  HeartRateDetailViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 02/09/25.
//

import UIKit
import SwiftUI
import Charts
import Combine

final class HeartRateDetailViewController: BaseViewController {
    
    // MARK: - IBOutlets
    @IBOutlet private weak var chartContainerView: UIView!     // <-- connect this
    @IBOutlet private weak var segmentedControl: UISegmentedControl!
    @IBOutlet private weak var lblRangeValue: UILabel!
    @IBOutlet private weak var lblDateRange: UILabel!
    @IBOutlet private weak var lblLatestTime: UILabel!
    @IBOutlet private weak var lblLatestValue: UILabel!
//    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    
    // MARK: - Properties
    private let viewModel = HeartRateDetailViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    private var host: UIHostingController<HeartRateCalmChartView>?   // <-- was HeartRateSwiftChartView
    private var currentPoints: [HeartPoint] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSegmentedControl()
        embedChartIfNeeded()
        bindViewModel()
        installPagingGestures() // swipe left/right to page
        viewModel.fetchInitialData(for: .hourly) // Hourly by default
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.startLiveHR()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopLiveHR()
    }
    
    // MARK: - Setup
    
    private func setupSegmentedControl() {
        segmentedControl.removeAllSegments()
        for (idx, range) in HeartRateDetailViewModel.ChartTimeRange.allCases.enumerated() {
            segmentedControl.insertSegment(withTitle: range.title, at: idx, animated: false)
        }
        segmentedControl.selectedSegmentIndex = HeartRateDetailViewModel.ChartTimeRange.hourly.rawValue

        let normalTextAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.lightGray]
        let selectedTextAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white]
        segmentedControl.setTitleTextAttributes(normalTextAttributes, for: .normal)
        segmentedControl.setTitleTextAttributes(selectedTextAttributes, for: .selected)
    }
    
    /// Create the SwiftUI host **once** and pin it to `chartContainerView`.
    private func embedChartIfNeeded() {
        guard host == nil else { return }
        let chart = HeartRateCalmChartView(
            points: currentPoints,
            range: viewModel.selectedRange,
            domain: viewModel.xDomain
        )
        let hosting = UIHostingController(rootView: chart)
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        chartContainerView.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: chartContainerView.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: chartContainerView.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: chartContainerView.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: chartContainerView.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
        host = hosting
    }
    
    /// Update the existing host by swapping its root view (no re-adding).
    private func updateChart(points: [HeartPoint]) {
        currentPoints = points
        guard let host else { return embedChartIfNeeded() }
        host.rootView = HeartRateCalmChartView(
            points: points,
            range: viewModel.selectedRange,
            domain: viewModel.xDomain
        )
    }
    
    private func installPagingGestures() {
        let left = UISwipeGestureRecognizer(target: self, action: #selector(didSwipeLeft))
        left.direction = .left
        chartContainerView.addGestureRecognizer(left)

        let right = UISwipeGestureRecognizer(target: self, action: #selector(didSwipeRight))
        right.direction = .right
        chartContainerView.addGestureRecognizer(right)
    }
    
    private func bindViewModel() {
        // Points -> Chart
        viewModel.$points
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pts in
                self?.updateChart(points: pts)
            }
            .store(in: &cancellables)
        
        // Labels
        viewModel.$headerDateText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.lblDateRange.text = $0 }
            .store(in: &cancellables)
        
        viewModel.$rangeText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.lblRangeValue.text = $0 }
            .store(in: &cancellables)
        
        viewModel.$latestTimeText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.lblLatestTime.text = $0 }
            .store(in: &cancellables)
        
        viewModel.$latestValueText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.lblLatestValue.text = $0 }
            .store(in: &cancellables)
        
        // Loading (optional)
//        viewModel.onIsLoading = { [weak self] loading in
//            DispatchQueue.main.async {
//                loading ? self?.activityIndicator.startAnimating()
//                        : self?.activityIndicator.stopAnimating()
//            }
//        }
    }
    
    @objc private func didSwipeLeft() { // older period
        viewModel.loadPreviousPeriod()
    }

    @objc private func didSwipeRight() { // newer period (capped at now)
        viewModel.loadNextPeriod()
    }
    
    // MARK: - Actions
    
    @IBAction private func segmentedControlChanged(_ sender: UISegmentedControl) {
        guard let range = HeartRateDetailViewModel.ChartTimeRange(rawValue: sender.selectedSegmentIndex) else { return }
        viewModel.fetchInitialData(for: range)
        updateChart(points: currentPoints)  // re-render with new timeframe styling
    }
    
    @IBAction private func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
}
