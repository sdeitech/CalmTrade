//
//  StepsDetailViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/09/25.
//


import UIKit
import SwiftUI
import Combine

final class StepsDetailViewController: BaseViewController {
    private enum ChartTransitionStyle: Equatable {
        case none
        case crossDissolve
        case slideFromLeft
        case slideFromRight
    }
    
    // MARK: - IBOutlets
    @IBOutlet private weak var chartContainerView: UIView!
    @IBOutlet private weak var segmentedControl: UISegmentedControl!
    @IBOutlet private weak var lblAverage: UILabel!
    @IBOutlet private weak var lblDateRange: UILabel!
    
    @IBOutlet private weak var subscriptionBlurView: UIVisualEffectView!
    
    // MARK: - MVVM
    private let viewModel = StepsDetailViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    // SwiftUI host
    private var host: UIHostingController<StepsSwiftChartView>?
    private var pendingTransitionStyle: ChartTransitionStyle = .none
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSegmentedControl()
        embedChartIfNeeded()
        bindViewModel()
        installPagingGestures()
        
        viewModel.fetchInitialData(for: .weekly) // default like Health
    }
    
    override func viewWillAppear(_ animated: Bool) {
        subscriptionBlurView.isHidden = checkAccess()
    }
    
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        let vc = UIHostingController(rootView: StepsLogView(limit: 1000, newestFirst: true, daysBack: 14))
        vc.modalPresentationStyle = .formSheet
        present(vc, animated: true)
    }
    
    // MARK: - UI
    private func setupSegmentedControl() {
        segmentedControl.removeAllSegments()
        for (i, r) in StepsDetailViewModel.ChartTimeRange.allCases.enumerated() {
            let title: String = {
                switch r {
                case .daily: return "D"
                case .weekly: return "W"
                case .monthly: return "M"
                }
            }()
            segmentedControl.insertSegment(withTitle: title, at: i, animated: false)
        }
        segmentedControl.selectedSegmentIndex = 1 // W
        let normalAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.lightGray]
        let selAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white]
        segmentedControl.setTitleTextAttributes(normalAttr, for: .normal)
        segmentedControl.setTitleTextAttributes(selAttr, for: .selected)
    }
    
    private func embedChartIfNeeded() {
        guard host == nil else { return }
        // placeholder chart until first data arrives
        let chart = StepsSwiftChartView(
            bars: [],
            range: .weekly,
            xDomain: Date()...Date(),
            yMax: 0
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
    
    private func updateChart(bars: [StepBar], xDomain: ClosedRange<Date>, yMax: Double, range: StepsChartRange) {
        let nextView = StepsSwiftChartView(
            bars: bars,
            range: range,
            xDomain: xDomain,
            yMax: yMax
        )
        guard let host else { return }
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
    
    // MARK: - Bindings
    private func bindViewModel() {
        // Bars + axes
        Publishers.CombineLatest3(viewModel.$bars, viewModel.$xDomain, viewModel.$yMax)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bars, domain, yMax in
                guard let self = self else { return }
                let range: StepsChartRange = {
                    switch self.viewModel.currentRange {
                    case .daily: return .daily
                    case .weekly: return .weekly
                    case .monthly: return .monthly
                    }
                }()
                self.updateChart(bars: bars, xDomain: domain, yMax: yMax, range: range)
                self.logStepsDetail(range: range, bars: bars, domain: domain)
            }
            .store(in: &cancellables)
        
        // Labels
        viewModel.$averageText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.lblAverage.text = $0 }
            .store(in: &cancellables)
        
        viewModel.$headerDateText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.lblDateRange.text = $0 }
            .store(in: &cancellables)
    }
    
    private func checkAccess() -> Bool {
        switch FeatureGate.shared.access(for: FeatureKey.chartsForBiometric) {
        case .allowed: return true
        case .locked: return false
        }
    }

    @objc private func didSwipeLeft() { // newer period
        pendingTransitionStyle = viewModel.loadNextPeriod() ? .slideFromLeft : .none
    }

    @objc private func didSwipeRight() { // older period
        pendingTransitionStyle = viewModel.loadPreviousPeriod() ? .slideFromRight : .none
    }
    
    // MARK: - Actions
    // Keep your existing method:
    @IBAction private func segmentedChanged(_ sender: UISegmentedControl) {
        let range: StepsDetailViewModel.ChartTimeRange = {
            switch sender.selectedSegmentIndex {
            case 0: return .daily
            case 1: return .weekly
            default: return .monthly
            }
        }()
        pendingTransitionStyle = .crossDissolve
        viewModel.load(range: range)
    }
    
    // Add this bridge so the storyboard's connection resolves:
    @IBAction private func segmentedControlChanged(_ sender: UISegmentedControl) {
        segmentedChanged(sender)
    }
    
    
    @IBAction private func backTapped(_ sender: Any) {
        navigationController?.popViewController()
    }
    
    private func logStepsDetail(range: StepsChartRange, bars: [StepBar], domain: ClosedRange<Date>) {
        let start = domain.lowerBound
        let end = domain.upperBound
        let repo = CTMetricsRepository.shared
        
        let periodMerged = Int(StepEngine.stepsTotal(from: start, to: end).rounded())
        let periodPolar = repo.series(kind: .steps, from: start, to: end, source: .polar360)
            .reduce(0) { $0 + Int($1.value.rounded()) }
        let periodApple = repo.series(kind: .steps, from: start, to: end, source: .appleHealth)
            .reduce(0) { $0 + Int($1.value.rounded()) }
        let barsTotal = Int(bars.reduce(0.0) { $0 + $1.value }.rounded())
        
        print("=== StepsDetail \(rangeLabel(range)) ===")
        print("Window: \(start) -> \(end)")
        print("Chart Domain: \(domain.lowerBound) -> \(domain.upperBound)")
        print("Bars Count: \(bars.count)")
        print("Bars Total: \(barsTotal)")
        print("Merged Total (StepEngine): \(periodMerged)")
        print("Polar Raw Total: \(periodPolar)")
        print("Apple Raw Total: \(periodApple)")
        print("==============================")
    }
    
    private func rangeLabel(_ range: StepsChartRange) -> String {
        switch range {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
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
            view.layer.add(transition, forKey: "StepsChartPaging")
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
