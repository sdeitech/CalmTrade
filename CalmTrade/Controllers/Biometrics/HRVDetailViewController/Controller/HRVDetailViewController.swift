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

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.set(metric: metric)
        setupSegmented()
        bindViewModel()
        embedChartIfNeeded()
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
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white]
        segmentedControl.setTitleTextAttributes(attrs, for: .normal)
        segmentedControl.setTitleTextAttributes(attrs, for: .selected)
    }

    private func embedChartIfNeeded() {
        guard host == nil else { return }
        let chart = HRVRangeCalmChartView(points: [], range: .hourly)
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
        Publishers.CombineLatest3(viewModel.$points, viewModel.$yMax, viewModel.$currentChartRange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pts, yMax, chartRange in
                guard let self, let host = self.host else { return }
                host.rootView = HRVRangeCalmChartView(
                    points: pts,
                    range: {
                        switch chartRange {
                        case .hourly:  return .hourly
                        case .daily:   return .daily
                        case .weekly:  return .weekly
                        case .monthly: return .monthly
                        case .yearly:  return .yearly
                        }
                    }()
                )
            }
            .store(in: &cancellables)
    }
    
    private func checkAccess() -> Bool {
        switch FeatureGate.shared.access(for: FeatureKey.chartsForBiometric) {
        case .allowed: return true
        case .locked: return false
        }
    }

    // MARK: - Actions

    @IBAction private func segmentedControlChanged(_ sender: UISegmentedControl) {
        guard let r = HRVDetailViewModel.ChartTimeRange(rawValue: sender.selectedSegmentIndex) else { return }
        viewModel.fetch(for: r)
    }
    
    @IBAction private func btnSubscribeTapped(_ sender: Any) {
        FeatureGate.shared.presentUpgradeSheet(for: FeatureKey.chartsForBiometric, from: self)
    }

    @IBAction private func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }
}
