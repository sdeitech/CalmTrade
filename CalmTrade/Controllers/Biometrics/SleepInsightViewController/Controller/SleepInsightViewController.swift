//
//  SleepInsightViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/09/25.
//

import UIKit
import SwiftUI

class SleepInsightViewController: BaseViewController {

    // MARK: - Outlets
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var lblTimeAsleep: UILabel!
    @IBOutlet weak var lblSleepDate: UILabel!
    @IBOutlet weak var chartContainerView: UIView!

    // MARK: - Properties
    private let viewModel = SleepInsightViewModel()
    private var swiftUIChartVC: UIHostingController<SleepCycleChart>?
    private var currentAxisScale: AxisScale = .daily


    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSegmentedControl()
        setupViewModelBindings()
        viewModel.fetchInitialData(for: .daily)
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

            guard let start = uiData.chartStartDate, let end = uiData.chartEndDate else { return }
            self.setupOrUpdateSwiftUIChart(segments: uiData.sleepSegments,
                                           startDate: start,
                                           endDate: end,
                                           isPaginating: isPaginating)
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
        // Build a brand-new SwiftUI view every time (this is the correct way to update)
        let chart = SleepCycleChart(
            start: startDate,
            end: endDate,
            segments: segments,
            axisScale: currentAxisScale
        )

        if let host = self.swiftUIChartVC {
            // ✅ Update in place by assigning a NEW rootView (this triggers a redraw)
            host.rootView = chart
            return
        }

        // First-time setup
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


    // MARK: - Actions
    @IBAction func segmentedControlChanged(_ sender: UISegmentedControl) {
        guard let selectedRange = SleepInsightViewModel.ChartTimeRange(rawValue: sender.selectedSegmentIndex) else { return }

        // Map VM range → SwiftUI axis for rendering
        switch selectedRange {
        case .daily:   currentAxisScale = .daily
        case .weekly:  currentAxisScale = .weekly
        case .monthly: currentAxisScale = .monthly
        }

        // Ask VM to reload the corresponding data window
        viewModel.fetchInitialData(for: selectedRange)
    }


    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }
}
