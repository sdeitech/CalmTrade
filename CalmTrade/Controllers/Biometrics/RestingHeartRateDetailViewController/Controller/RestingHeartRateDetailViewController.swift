//
//  RestingHeartRateDetailViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 02/09/25.
//

import UIKit
import SwiftUI
import Combine

final class RestingHeartRateDetailViewController: BaseViewController {
    private enum ChartTransitionStyle: Equatable {
        case none
        case crossDissolve
        case slideFromLeft
        case slideFromRight
    }

    // MARK: - IBOutlets
    @IBOutlet private weak var chartContainerView: UIView!   // connect in IB
    @IBOutlet private weak var segmentedControl: UISegmentedControl!
    @IBOutlet private weak var lblAverage: UILabel!
    @IBOutlet private weak var lblDateRange: UILabel!
    
    @IBOutlet private weak var subscriptionBlurView: UIVisualEffectView!

    // MARK: - Properties
    private let viewModel = RestingHeartRateDetailViewModel()
    private var cancellables = Set<AnyCancellable>()
    private var host: UIHostingController<RestingHRSwiftChartView>?
    private var pendingTransitionStyle: ChartTransitionStyle = .none

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSegmentedControl()
        embedChartHost()
        bindViewModel()
        installPagingGestures()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshCurrentRange),
            name: .ctMetricsDidMirror,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshCurrentRange),
            name: .ctMetricUpdated,
            object: nil
        )
        viewModel.fetchInitialData(for: .weekly)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        subscriptionBlurView.isHidden = checkAccess()
    }

    // MARK: - Setup
    private func setupSegmentedControl() {
        segmentedControl.removeAllSegments()
        for (i, r) in RestingHeartRateDetailViewModel.ChartTimeRange.allCases.enumerated() {
            let title: String = {
                switch r { case .daily: return "D"; case .weekly: return "W"; case .monthly: return "M" }
            }()
            segmentedControl.insertSegment(withTitle: title, at: i, animated: false)
        }
        segmentedControl.selectedSegmentIndex = RestingHeartRateDetailViewModel.ChartTimeRange.weekly.rawValue

        let normal: [NSAttributedString.Key: Any]   = [.foregroundColor: UIColor.lightGray]
        let selected: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white]
        segmentedControl.setTitleTextAttributes(normal, for: .normal)
        segmentedControl.setTitleTextAttributes(selected, for: .selected)
    }

    private func embedChartHost() {
        let empty = RestingHRSwiftChartView(points: [],
                                            range: .weekly,
                                            xDomain: Date()...Date(),
                                            yMax: 0)

        let hosting = UIHostingController(rootView: empty)
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

    private func renderChart() {
        guard let host = host else { return }
        let shouldAnimateMetadata = pendingTransitionStyle != .none
        let range: RHRChartRange = {
            switch viewModel.selectedRange {
            case .daily:   return .daily
            case .weekly:  return .weekly
            case .monthly: return .monthly
            }
        }()
        let nextView = RestingHRSwiftChartView(points: viewModel.points,
                                               range: range,
                                               xDomain: viewModel.xDomain,
                                               yMax: viewModel.yMax)
        applyTransitionIfNeeded(on: host.view)
        host.rootView = nextView
        if shouldAnimateMetadata {
            animateMetadataRefresh()
        }
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
        viewModel.$points
            .combineLatest(viewModel.$xDomain, viewModel.$yMax, viewModel.$selectedRange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _,_,_,_ in self?.renderChart() }
            .store(in: &cancellables)

        viewModel.$averageText
            .map { Optional($0) }                    // String -> String?
            .receive(on: DispatchQueue.main)
            .assign(to: \.text, on: lblAverage)      // keyPath is String?
            .store(in: &cancellables)

        viewModel.$headerDateText
            .map { Optional($0) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.text, on: lblDateRange)
            .store(in: &cancellables)

        viewModel.onIsLoading = { _ in } // plug in spinner if you add one
    }
    
    private func checkAccess() -> Bool {
        switch FeatureGate.shared.access(for: FeatureKey.chartsForBiometric) {
        case .allowed: return true
        case .locked: return false
        }
    }

    // MARK: - Actions
    @IBAction private func segmentedControlChanged(_ sender: UISegmentedControl) {
        guard let r = RestingHeartRateDetailViewModel.ChartTimeRange(rawValue: sender.selectedSegmentIndex) else { return }
        pendingTransitionStyle = .crossDissolve
        viewModel.fetchInitialData(for: r)
    }

    @objc private func refreshCurrentRange() {
        viewModel.refreshCurrentRange()
    }

    @objc private func didSwipeLeft() { // newer period
        pendingTransitionStyle = viewModel.loadNextPeriod() ? .slideFromLeft : .none
    }

    @objc private func didSwipeRight() { // older period
        pendingTransitionStyle = viewModel.loadPreviousPeriod() ? .slideFromRight : .none
    }

    @IBAction private func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }
    
    @IBAction private func btnSubscribeTapped(_ sender: Any) {
        FeatureGate.shared.presentUpgradeSheet(for: FeatureKey.chartsForBiometric, from: self)
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
            view.layer.add(transition, forKey: "RestingHRChartPaging")
        }
    }

    private func animateMetadataRefresh() {
        let views = [lblAverage, lblDateRange]
        UIView.animate(withDuration: 0.16, animations: {
            views.forEach { $0?.alpha = 0.72 }
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                views.forEach { $0?.alpha = 1.0 }
            }
        }
    }
}
