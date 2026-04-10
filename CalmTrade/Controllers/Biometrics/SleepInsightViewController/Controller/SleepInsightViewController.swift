//
//  SleepInsightViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/09/25.
//

import UIKit
import SwiftUI

class SleepInsightViewController: BaseViewController {
    private enum ChartTransitionStyle: Equatable {
        case none
        case crossDissolve
        case slideFromLeft
        case slideFromRight
    }

    // MARK: - Outlets
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var lblTimeAsleep: UILabel!
    @IBOutlet weak var lblSleepDate: UILabel!
    @IBOutlet weak var chartContainerView: UIView!
    
    @IBOutlet private weak var subscriptionBlurView: UIVisualEffectView!
    
    @IBOutlet weak var lblAwakeTime: UILabel!
    @IBOutlet weak var lblREMTime: UILabel!
    @IBOutlet weak var lblCoreTime: UILabel!
    @IBOutlet weak var lblDeepTime: UILabel!

    // MARK: - Properties
    private let viewModel = SleepInsightViewModel()
    private var swiftUIChartVC: UIHostingController<SleepCycleChart>?
    private var currentAxisScale: AxisScale = .daily
    private var pendingTransitionStyle: ChartTransitionStyle = .none


    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSegmentedControl()
        setupViewModelBindings()
        installPagingGestures()
        viewModel.fetchInitialData(for: .daily)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        subscriptionBlurView.isHidden = checkAccess()
    }
    
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        let host = UIHostingController(rootView: SleepLogView(limit: nil, newestFirst: true))
        host.modalPresentationStyle = .formSheet
        present(host, animated: true)
    }

    // MARK: - Bindings
    private func setupViewModelBindings() {
        viewModel.onDataUpdate = { [weak self] uiData, isPaginating in
            guard let self = self else { return }

            self.lblTimeAsleep.attributedText = uiData.timeAsleepAttributedText
            self.lblSleepDate.text = uiData.sleepDate

            self.lblAwakeTime.attributedText = self.viewModel.formatStageTime(uiData.awakeSeconds)
            self.lblREMTime.attributedText   = self.viewModel.formatStageTime(uiData.remSeconds)
            self.lblCoreTime.attributedText  = self.viewModel.formatStageTime(uiData.coreSeconds)
            self.lblDeepTime.attributedText  = self.viewModel.formatStageTime(uiData.deepSeconds)

            guard let start = uiData.chartStartDate,
                  let end = uiData.chartEndDate else { return }

            self.setupOrUpdateSwiftUIChart(
                segments: uiData.sleepSegments,
                startDate: start,
                endDate: end,
                isPaginating: isPaginating
            )
        }
    }

    // MARK: - UI

    private func setupSegmentedControl() {
        segmentedControl.removeAllSegments()
        for (i, range) in SleepInsightViewModel.ChartTimeRange.allCases.enumerated() {
            segmentedControl.insertSegment(withTitle: range.title, at: i, animated: false)
        }
        segmentedControl.selectedSegmentIndex = SleepInsightViewModel.ChartTimeRange.daily.rawValue

        let normal = [NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        let selected = [NSAttributedString.Key.foregroundColor: UIColor.white]
        segmentedControl.setTitleTextAttributes(normal, for: .normal)
        segmentedControl.setTitleTextAttributes(selected, for: .selected)
    }

    private func setupOrUpdateSwiftUIChart(segments: [SleepSegment],
                                           startDate: Date,
                                           endDate: Date,
                                           isPaginating: Bool)
    {
        let chart = SleepCycleChart(
            start: startDate,
            end: endDate,
            segments: segments,
            axisScale: currentAxisScale
        )

        if let host = self.swiftUIChartVC {
            applyTransitionIfNeeded(on: host.view)
            host.rootView = chart
            animateMetadataRefresh()
            return
        }

        let host = UIHostingController(rootView: chart)
        addChild(host)
        chartContainerView.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        chartContainerView.clipsToBounds = true
        chartContainerView.layer.masksToBounds = true

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: chartContainerView.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: chartContainerView.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: chartContainerView.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: chartContainerView.trailingAnchor)
        ])

        host.didMove(toParent: self)
        self.swiftUIChartVC = host
    }

    private func installPagingGestures() {
        let left = UISwipeGestureRecognizer(target: self, action: #selector(didSwipeLeft))
        left.direction = .left
        chartContainerView.addGestureRecognizer(left)

        let right = UISwipeGestureRecognizer(target: self, action: #selector(didSwipeRight))
        right.direction = .right
        chartContainerView.addGestureRecognizer(right)
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
    @IBAction func segmentedControlChanged(_ sender: UISegmentedControl) {
        guard let selectedRange = SleepInsightViewModel.ChartTimeRange(rawValue: sender.selectedSegmentIndex) else { return }

        // Map VM range → SwiftUI axis for rendering
        switch selectedRange {
        case .daily:   currentAxisScale = .daily
        case .weekly:  currentAxisScale = .weekly
        case .monthly: currentAxisScale = .monthly
        }

        pendingTransitionStyle = .crossDissolve
        viewModel.fetchInitialData(for: selectedRange)
    }


    @IBAction func btnBackTapped(_ sender: Any) {
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
            view.layer.add(transition, forKey: "SleepChartPaging")
        }
    }

    private func animateMetadataRefresh() {
        let views = [lblTimeAsleep, lblSleepDate, lblAwakeTime, lblREMTime, lblCoreTime, lblDeepTime]
        UIView.animate(withDuration: 0.16, animations: {
            views.forEach { $0?.alpha = 0.72 }
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                views.forEach { $0?.alpha = 1.0 }
            }
        }
    }
}
