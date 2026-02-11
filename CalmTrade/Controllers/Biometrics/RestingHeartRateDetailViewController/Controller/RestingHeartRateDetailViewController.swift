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

    // MARK: - IBOutlets
    @IBOutlet private weak var chartContainerView: UIView!   // connect in IB
    @IBOutlet private weak var segmentedControl: UISegmentedControl!
    @IBOutlet private weak var lblAverage: UILabel!
    @IBOutlet private weak var lblDateRange: UILabel!

    // MARK: - Properties
    private let viewModel = RestingHeartRateDetailViewModel()
    private var cancellables = Set<AnyCancellable>()
    private var host: UIHostingController<RestingHRSwiftChartView>?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSegmentedControl()
        embedChartHost()
        bindViewModel()
        viewModel.fetchInitialData(for: .weekly)
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
        let range: RHRChartRange = {
            switch viewModel.selectedRange {
            case .daily:   return .daily
            case .weekly:  return .weekly
            case .monthly: return .monthly
            }
        }()
        host.rootView = RestingHRSwiftChartView(points: viewModel.points,
                                                range: range,
                                                xDomain: viewModel.xDomain,
                                                yMax: viewModel.yMax)
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

    // MARK: - Actions
    @IBAction private func segmentedControlChanged(_ sender: UISegmentedControl) {
        guard let r = RestingHeartRateDetailViewModel.ChartTimeRange(rawValue: sender.selectedSegmentIndex) else { return }
        viewModel.fetchInitialData(for: r)
    }

    @IBAction private func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }
}

