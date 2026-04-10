//
//  HRVDetailViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 02/09/25.
//


// HRVDetailViewController.swift

import UIKit
import SwiftUI
import Combine

final class HRVDetailViewController: BaseViewController {
    private enum ChartTransitionStyle: Equatable {
        case none
        case crossDissolve
        case slideFromLeft
        case slideFromRight
    }

    // MARK: - Inputs
    var metric: HRVMetricType = .rmssd   // set by caller (Biometrics VC)

    // MARK: - Outlets
    @IBOutlet private weak var segmentedControl: UISegmentedControl!
    @IBOutlet private weak var lblAverageValue: UILabel!
    @IBOutlet private weak var lblDateRange: UILabel!
    @IBOutlet private weak var chartContainerView: UIView!
    @IBOutlet private weak var lblHrvDetail: UILabel!
    @IBOutlet private weak var lblTitle: UILabel!
    
    @IBOutlet private weak var subscriptionBlurView: UIVisualEffectView!

    // MARK: - State
    private let viewModel = HRVDetailViewModel()
    private var cancellables = Set<AnyCancellable>()
    private var host: UIHostingController<HRVRangeCalmChartView>?
    private var currentPoints: [HRVRangeCalmChartView.HRVRangePoint] = []
    private var pendingTransitionStyle: ChartTransitionStyle = .none

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.set(metric: metric)
        setupSegmented()
        embedChartIfNeeded()
        bindViewModel()
        installPagingGestures()
        viewModel.fetch(for: .hourly) // align with HR screens; pick your default
        lblTitle.text = (metric == .rmssd) ? "HRV • RMSSD" : "HRV • SDNN"
        lblHrvDetail.text = viewModel.hrvDetailText
    }
    
    override func viewWillAppear(_ animated: Bool) {
        subscriptionBlurView.isHidden = checkAccess()
    }

    private func setupSegmented() {
        segmentedControl.removeAllSegments()
        for (i, r) in HRVDetailViewModel.ChartTimeRange.allCases.enumerated() {
            segmentedControl.insertSegment(withTitle: r.title, at: i, animated: false)
        }
        segmentedControl.selectedSegmentIndex = HRVDetailViewModel.ChartTimeRange.hourly.rawValue
        let normalTextAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.lightGray]
        let selectedTextAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white]
        segmentedControl.setTitleTextAttributes(normalTextAttributes, for: .normal)
        segmentedControl.setTitleTextAttributes(selectedTextAttributes, for: .selected)
    }

    private func embedChartIfNeeded() {
        guard host == nil else { return }
        let chart = HRVRangeCalmChartView(
            points: currentPoints,
            range: .hourly,
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

    private func updateChart(points: [HRVRangeCalmChartView.HRVRangePoint]) {
        currentPoints = points
        guard let host else { return embedChartIfNeeded() }
        let nextView = HRVRangeCalmChartView(
            points: points,
            range: chartRange(for: viewModel.selectedRange),
            domain: viewModel.xDomain
        )
        applyTransitionIfNeeded(on: host.view)
        host.rootView = nextView
        animateMetadataRefresh()
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
        // labels
        viewModel.$averageText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.lblAverageValue.text = $0 }
            .store(in: &cancellables)

        viewModel.$dateRangeText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.lblDateRange.text = $0 }
            .store(in: &cancellables)

        // chart updates
        viewModel.$points
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pts in
                self?.updateChart(points: pts)
            }
            .store(in: &cancellables)
    }
    
    private func checkAccess() -> Bool {
        switch FeatureGate.shared.access(for: FeatureKey.chartsForBiometric) {
        case .allowed: return true
        case .locked: return false
        }
    }

    @objc private func didSwipeLeft() {
        pendingTransitionStyle = viewModel.loadNextPeriod() ? .slideFromLeft : .none
    }

    @objc private func didSwipeRight() {
        pendingTransitionStyle = viewModel.loadPreviousPeriod() ? .slideFromRight : .none
    }

    // MARK: - Actions

    @IBAction private func segmentedControlChanged(_ sender: UISegmentedControl) {
        guard let r = HRVDetailViewModel.ChartTimeRange(rawValue: sender.selectedSegmentIndex) else { return }
        pendingTransitionStyle = .crossDissolve
        viewModel.fetch(for: r)
    }
    
    @IBAction private func btnSubscribeTapped(_ sender: Any) {
        FeatureGate.shared.presentUpgradeSheet(for: FeatureKey.chartsForBiometric, from: self)
    }

    @IBAction private func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }

    private func chartRange(for range: HRVDetailViewModel.ChartTimeRange) -> HRVRangeCalmChartView.TimeRange {
        switch range {
        case .hourly: return .hourly
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .yearly: return .yearly
        }
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
            transition.timingFunction = CAMediaTimingFunction(name: .easeIn)
            transition.subtype = pendingTransitionStyle == .slideFromLeft ? .fromRight : .fromLeft
            view.layer.add(transition, forKey: "HRVChartPaging")
        }
    }

    private func animateMetadataRefresh() {
        let views = [lblAverageValue, lblDateRange]
        UIView.animate(withDuration: 0.16, animations: {
            views.forEach { $0?.alpha = 0.72 }
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                views.forEach { $0?.alpha = 1.0 }
            }
        }
    }
}
