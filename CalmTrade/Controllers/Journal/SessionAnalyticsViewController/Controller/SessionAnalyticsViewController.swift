//
//  SessionAnalyticsViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 13/01/26.
//


import UIKit

final class SessionAnalyticsViewController: UIViewController {

    // MARK: - IBOutlets

    // P/L
    @IBOutlet weak var plLabel: UILabel!
    @IBOutlet weak var netPlLabel: UILabel!

    // Win Rate
    @IBOutlet weak var winRateLabel: UILabel!
    @IBOutlet weak var winLossLabel: UILabel!

    // Drawdown
    @IBOutlet weak var drawdownLabel: UILabel!
    @IBOutlet weak var drawdownNetPlLabel: UILabel!

    // CalmScore
    @IBOutlet weak var calmScoreLabel: UILabel!
    @IBOutlet weak var calmStateLabel: UILabel!
    @IBOutlet weak var sleepLabel: UILabel!

    // MARK: - VM
    let viewModel = SessionAnalyticsViewModel()

    var selectedDate: String!   // yyyy-MM-dd

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
        viewModel.fetch(date: selectedDate)
    }

    // MARK: - Binding
    private func bindViewModel() {
        viewModel.onLoading = { isLoading in
            // show/hide loader if needed
        }

        viewModel.onError = { [weak self] message in
            self?.showAlert(message: message)
        }

        viewModel.onUpdate = { [weak self] in
            self?.render()
        }
    }

    // MARK: - Render UI
    private func render() {
        guard let data = viewModel.data else { return }
        
        // --- P/L ---
        plLabel.text = data.pl.label
        plLabel.textColor = data.pl.valueR >= 0 ? .systemGreen : .systemRed
        netPlLabel.text = data.pl.subLabel
        
        // --- Win Rate ---
        winRateLabel.text = data.winRate.label
        winLossLabel.text = data.winRate.subLabel
        
        // --- Drawdown ---
        drawdownLabel.text = data.drawdown.label
        drawdownLabel.textColor = data.drawdown.maxDrawdownR < 0 ? .systemRed : .systemGreen
        drawdownNetPlLabel.text = data.drawdown.subLabel
        
        // --- CalmScore ---
        if let score = data.calmScore.value {
            calmScoreLabel.text = "\(score)"
            calmStateLabel.text = data.calmScore.stressLevel ?? "—"
        } else {
            calmScoreLabel.text = "--"
            calmStateLabel.text = "No Data"
        }
        
        if let sleep = data.calmScore.sleepHours {
            sleepLabel.text = "Sleep \(sleep)h"
            sleepLabel.isHidden = false
        } else {
            sleepLabel.isHidden = true
        }
    }
}
