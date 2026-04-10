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
        applyLoadingState()
        viewModel.loadData()
    }

    private func setupBindings() {
        viewModel.onLoadingChanged = { [weak self] isLoading in
            guard let self else { return }
            if isLoading {
                self.applyLoadingState()
            }
        }

        viewModel.onDataLoaded = { [weak self] model in

            guard let self = self else { return }

            self.statusLabel.text = model.status
            self.statusLabel.textColor = model.statusUsesFallback ? .systemOrange : .systemTeal

            self.ansTitleLabel.text = model.ansTitle
            self.ansValueLabel.text = model.ansRateText

            self.sleepTitleLabel.text = model.sleepTitle
            self.usualSleepLabel.text = model.usualSleepText

            self.barsView.updateBars(level: model.statusLevel)

            self.ansIndicatorView.configure(
                valueText: model.ansDeviationText,
                offsetRatio: model.ansOffsetRatio
            )

            self.sleepIndicatorView.configure(
                valueText: model.sleepScoreText,
                offsetRatio: model.sleepOffsetRatio
            )
        }

        viewModel.onError = { [weak self] message in
            self?.applyErrorState(message: message)
        }
    }

    private func applyLoadingState() {
        statusLabel.text = "Loading..."
        statusLabel.textColor = .white
        ansTitleLabel.text = "--"
        ansValueLabel.text = "--"
        sleepTitleLabel.text = "--"
        usualSleepLabel.text = "Score --"
        barsView.updateBars(level: 0.25)
        ansIndicatorView.configure(valueText: "--", offsetRatio: 0)
        sleepIndicatorView.configure(valueText: "--", offsetRatio: 0)
    }

    private func applyErrorState(message: String) {
        statusLabel.text = "Unavailable"
        statusLabel.textColor = .systemGray2
        ansTitleLabel.text = message
        ansValueLabel.text = "--"
        sleepTitleLabel.text = "--"
        usualSleepLabel.text = "Score --"
        barsView.updateBars(level: 0.2)
        ansIndicatorView.configure(valueText: "--", offsetRatio: 0)
        sleepIndicatorView.configure(valueText: "--", offsetRatio: 0)
    }
}
