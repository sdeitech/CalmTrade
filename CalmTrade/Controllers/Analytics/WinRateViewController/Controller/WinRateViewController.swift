//
//  WinRateViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 27/11/25.
//


import UIKit
import SwiftUI
import Combine

final class WinRateViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var lblWins: UILabel!
    @IBOutlet weak var lblLosses: UILabel!
    @IBOutlet weak var lblTrend: UILabel!
    @IBOutlet weak var imgTrend: UIImageView!
    @IBOutlet weak var gaugeContainer: UIView!
    @IBOutlet weak var lblAverageCalmScore: UILabel!

    // MARK: - Properties
    private let viewModel = WinRateViewModel()
    private var cancellables = Set<AnyCancellable>()
    private var gaugeHostVC: UIHostingController<WinRateGauge>?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
        loadInitial()
    }

    private func loadInitial() {
        viewModel.fetch(filter: .weekly)
        segmentedControl.selectedSegmentIndex = 1
    }

    private func bindViewModel() {

        // Gauge + Avg Calmscore
        viewModel.$winRate
            .combineLatest(viewModel.$avgCalmScore)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (rate, avg) in
                self?.updateGauge(rate)
            }
            .store(in: &cancellables)

        // Wins
        viewModel.$wins
            .receive(on: DispatchQueue.main)
            .sink { [weak self] wins in
                self?.lblWins.text = "\(wins)"
            }
            .store(in: &cancellables)

        // Losses
        viewModel.$losses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] losses in
                self?.lblLosses.text = String(format: "%02d", losses)
            }
            .store(in: &cancellables)

        // Trend
        viewModel.$trendPercent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] percent in
                let positive = percent >= 0
                self?.lblTrend.text = "\(positive ? "+" : "")\(percent)% from last period"
                self?.lblTrend.textColor = positive ? UIColor.green : UIColor.red
                self?.imgTrend.tintColor = positive ? UIColor.green : UIColor.red
                self?.imgTrend.image = UIImage(systemName: positive ? "arrow.up.right" : "arrow.down.right")
            }
            .store(in: &cancellables)
    }

    // MARK: Gauge Embedding
    private func updateGauge(_ score: Int) {
        gaugeHostVC?.view.removeFromSuperview()
        gaugeHostVC?.removeFromParent()

        let gauge = WinRateGauge(score: Double(score))
        let host = UIHostingController(rootView: gauge)
        gaugeHostVC = host
        host.view.backgroundColor = .clear

        addChild(host)
        gaugeContainer.addSubview(host.view)

        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: gaugeContainer.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: gaugeContainer.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: gaugeContainer.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: gaugeContainer.bottomAnchor)
        ])

        host.didMove(toParent: self)
    }

    // MARK: Segmented Control
    @IBAction func didChangeSegment(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0: viewModel.fetch(filter: .daily)
        case 1: viewModel.fetch(filter: .weekly)
        case 2: viewModel.fetch(filter: .monthly)
        case 3: viewModel.fetch(filter: .yearly)
        default: break
        }
    }
    
    @IBAction func didTapBackButton(_ sender: Any) {
        navigationController?.popViewController()
    }
}
