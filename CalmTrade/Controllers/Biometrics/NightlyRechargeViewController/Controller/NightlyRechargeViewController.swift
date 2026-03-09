//
//  NightlyRechargeViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 09/03/26.
//


import UIKit

final class NightlyRechargeViewController: UIViewController {

    @IBOutlet weak var barsView: NightlyRechargeBarsView!

    @IBOutlet weak var statusLabel: UILabel!

    @IBOutlet weak var ansTitleLabel: UILabel!
    @IBOutlet weak var ansValueLabel: UILabel!
    @IBOutlet weak var ansIndicatorView: BaselineIndicatorView!

    @IBOutlet weak var sleepTitleLabel: UILabel!
    @IBOutlet weak var usualSleepLabel: UILabel!
    @IBOutlet weak var sleepIndicatorView: BaselineIndicatorView!

    private let viewModel = NightlyRechargeViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBindings()
        viewModel.loadData()
    }

    private func setupBindings() {

        viewModel.onDataLoaded = { [weak self] model in

            guard let self = self else { return }

            self.statusLabel.text = model.status

            self.ansTitleLabel.text = model.ansTitle
            self.ansValueLabel.text = "0"

            self.sleepTitleLabel.text = model.sleepTitle
            self.usualSleepLabel.text = "Usual \(model.usualSleep)"

            self.barsView.updateBars(level: 0.95)

            self.ansIndicatorView.configure(
                valueText: "+\(model.ansDeviation)",
                offsetRatio: 0.35
            )

            self.sleepIndicatorView.configure(
                valueText: "\(model.sleepScore)",
                offsetRatio: 0.45
            )
        }
    }
}