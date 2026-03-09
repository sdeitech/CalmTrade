//
//  AverageTradeGainLossViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/12/25.
//


import UIKit
import KRProgressHUD

final class AverageTradeGainLossViewController: UIViewController {

    // MARK: - IBOutlets (Connect these from storyboard)
    @IBOutlet weak var lblGain: UILabel!
    @IBOutlet weak var lblLoss: UILabel!
    @IBOutlet weak var lblInsight: UILabel!

    @IBOutlet weak var lblAvgGain: UILabel!
    @IBOutlet weak var barAvgGain: UIProgressView!

    @IBOutlet weak var lblAvgLoss: UILabel!
    @IBOutlet weak var barAvgLoss: UIProgressView!

    @IBOutlet weak var lblNetAvg: UILabel!
    @IBOutlet weak var barNetAvg: UIProgressView!

    @IBOutlet weak var segmentControl: UISegmentedControl!   // Daily / Weekly / Monthly / Yearly

    private let vm = AverageTradeGainLossViewModel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVM()
        loadData()
    }

    private func setupVM() {
        vm.onLoading = { isLoading in
            isLoading ? LoaderManager.shared.show() : LoaderManager.shared.hide()
        }

        vm.onData = { [weak self] data in
            self?.applyData(data)
        }

        vm.onError = { msg in
            KRProgressHUD.showError(withMessage: msg)
        }
    }

    private func loadData() {
        let filter = filterValue(for: segmentControl.selectedSegmentIndex)
        vm.fetch(filter: filter)
    }

    private func filterValue(for index: Int) -> String {
        switch index {
        case 0: return "daily"
        case 1: return "weekly"
        case 2: return "monthly"
        case 3: return "yearly"
        default: return "weekly"
        }
    }

    // MARK: - UI Rendering
    private func applyData(_ m: AverageTradeGainLossResponse) {

        // MAIN TILE
        lblGain.text = formatCurrency(m.avgGain)
        lblLoss.text = formatCurrency(m.avgLoss)
        lblInsight.text = generateInsight(m)

        // BREAKDOWN

        lblAvgGain.text = formatCurrency(m.performanceBreakdown.avgTradeGain.value)
        barAvgGain.setProgress(Float(m.performanceBreakdown.avgTradeGain.progress), animated: true)

        lblAvgLoss.text = formatCurrency(m.performanceBreakdown.avgTradeLoss.value)
        barAvgLoss.setProgress(Float(m.performanceBreakdown.avgTradeLoss.progress), animated: true)

        lblNetAvg.text = formatCurrency(m.performanceBreakdown.netAvgPerformance.value)
        barNetAvg.setProgress(Float(m.performanceBreakdown.netAvgPerformance.progress), animated: true)
    }

    // MARK: - Helpers
    private func formatCurrency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(String(format: "%.2f", abs(value)))"
    }

    private func generateInsight(_ m: AverageTradeGainLossResponse) -> String {
        // Customize this later based on HR, calmScore, streaks
        return "Loss streaks follow HR > \(m.biometrics.heartRate) + \"Frustrated\""
    }
    
    // MARK: - Actions
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        loadData()
    }
    
    @IBAction func backButtonTapped(_ sender: Any) {
        navigationController?.popViewController()
    }
}
