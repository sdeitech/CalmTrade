//
//  ProfitFactorViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 08/12/25.
//


import UIKit
import Combine
import SwiftUI

final class ProfitFactorViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var gaugeContainer: UIView!

    @IBOutlet weak var lblWins: UILabel!
    @IBOutlet weak var lblLosses: UILabel!

    @IBOutlet weak var winProgressView: UIProgressView!
    @IBOutlet weak var lossProgressView: UIProgressView!

    @IBOutlet weak var segmentedControl: UISegmentedControl!

    // Hosting controller for SwiftUI gauge
    private var hosting: UIHostingController<ProfitFactorGauge>?

    private var vm = ProfitFactorViewModel()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureProgressViews()
        bindVM()
        vm.fetchProfitFactor(filter: "weekly")
    }

    // MARK: - UI Setup
    private func configureProgressViews() {
        winProgressView.progressTintColor = UIColor.systemGreen
        lossProgressView.progressTintColor = UIColor.systemRed

        let trackColor = UIColor.white.withAlphaComponent(0.15)
        winProgressView.trackTintColor = trackColor
        lossProgressView.trackTintColor = trackColor

        winProgressView.progress = 0
        lossProgressView.progress = 0
    }

    // MARK: - Binding
    private func bindVM() {
        vm.reload
            .sink { [weak self] in
                self?.updateUI()
            }
            .store(in: &cancellables)
    }

    // MARK: - UI Update
    private func updateUI() {
        // Wins & losses values
        lblWins.text = vm.winsValueText
        lblLosses.text = vm.lossesValueText

        // Progress bars
        winProgressView.setProgress(vm.winProgress, animated: true)
        lossProgressView.setProgress(vm.lossProgress, animated: true)

        // Gauge update
        loadGauge()
    }

    // MARK: - SwiftUI Gauge Loader
    private func loadGauge() {
        hosting?.view.removeFromSuperview()
        hosting?.removeFromParent()

        let gauge = ProfitFactorGauge(
            percent: vm.gaugePercent,
            winValue: vm.wins,          // positive number
            lossValue: vm.losses        // absolute positive number
        )

        let hc = UIHostingController(rootView: gauge)
        hosting = hc

        addChild(hc)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        gaugeContainer.addSubview(hc.view)

        NSLayoutConstraint.activate([
            hc.view.leadingAnchor.constraint(equalTo: gaugeContainer.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: gaugeContainer.trailingAnchor),
            hc.view.topAnchor.constraint(equalTo: gaugeContainer.topAnchor),
            hc.view.bottomAnchor.constraint(equalTo: gaugeContainer.bottomAnchor)
        ])

        hc.didMove(toParent: self)
    }

    // MARK: - Segmented control
    @IBAction func filterChanged(_ sender: UISegmentedControl) {
        let filter = ["daily", "weekly", "monthly", "yearly"][sender.selectedSegmentIndex]
        vm.fetchProfitFactor(filter: filter)
    }
}

