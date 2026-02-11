//
//  NotificationSettingsViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/02/26.
//


import UIKit

final class NotificationSettingsViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var stockSwitch: UISwitch!
    @IBOutlet weak var heartRateSwitch: UISwitch!
    @IBOutlet weak var subscriptionSwitch: UISwitch!
    @IBOutlet weak var polarSwitch: UISwitch!
    @IBOutlet weak var emotionalSwitch: UISwitch!

    // MARK: - ViewModel
    private let viewModel = NotificationSettingsViewModel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
        viewModel.fetchSettings()
    }

    // MARK: - Bindings
    private func bindViewModel() {
        viewModel.onSettingsFetched = { [weak self] settings in
            self?.apply(settings)
        }

        viewModel.onError = { [weak self] message in
            self?.showAlert(message)
        }
    }

    private func apply(_ settings: NotificationSettings) {
        stockSwitch.isOn = settings.stockDetails
        heartRateSwitch.isOn = settings.heartRateIndications
        subscriptionSwitch.isOn = settings.subscriptionOffers
        polarSwitch.isOn = settings.polarUpdates
        emotionalSwitch.isOn = settings.emotionalSuggestions
    }

    // MARK: - Actions
    @IBAction func stockChanged(_ sender: UISwitch) {
        viewModel.updateSetting(\.stockDetails, value: sender.isOn)
    }

    @IBAction func heartRateChanged(_ sender: UISwitch) {
        viewModel.updateSetting(\.heartRateIndications, value: sender.isOn)
    }

    @IBAction func subscriptionChanged(_ sender: UISwitch) {
        viewModel.updateSetting(\.subscriptionOffers, value: sender.isOn)
    }

    @IBAction func polarChanged(_ sender: UISwitch) {
        viewModel.updateSetting(\.polarUpdates, value: sender.isOn)
    }

    @IBAction func emotionalChanged(_ sender: UISwitch) {
        viewModel.updateSetting(\.emotionalSuggestions, value: sender.isOn)
    }
    
    @IBAction func btnBackClk(_ sender: UIButton) {
        self.navigationController?.popViewController()
    }

    // MARK: - Helpers
    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Error",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
