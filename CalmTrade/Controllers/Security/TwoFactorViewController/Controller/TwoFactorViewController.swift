//
//  TwoFactorViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 05/01/26.
//

import UIKit
import KRProgressHUD
import SwiftUI

final class TwoFactorViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var twoFASwitch: UISwitch!

    // MARK: - Dependencies
    private let viewModel = TwoFactorViewModel()

    // You should already have this from profile API
    private var is2FAEnabled: Bool = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        bindViewModel()
    }

    // MARK: - UI Setup
    private func configureUI() {
        is2FAEnabled = SessionManager.shared.current?.twoFactorEnabled ?? false
        updateUI(enabled: is2FAEnabled)
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            guard let self else { return }

            switch state {
            case .idle:
                LoaderManager.shared.hide()

            case .loading:
                LoaderManager.shared.show()

            case .showOTP:
                LoaderManager.shared.hide()
                self.presentOTPVerification(isDisabling: false)

            case .error(let message):
                LoaderManager.shared.hide()
                self.revertSwitch()
                self.showError(message)
            }
        }
    }

    // MARK: - Actions
    @IBAction private func twoFASwitchChanged(_ sender: UISwitch) {
        sender.isEnabled = false // lock switch until flow finishes

        if sender.isOn {
            viewModel.enable2FA(email: SessionManager.shared.current?.email ?? "")
        } else {
            presentOTPVerification(isDisabling: true)
        }
    }
    
    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }

    // MARK: - Navigation
    private func presentOTPVerification(isDisabling: Bool) {
        let vm = OTPVerificationViewModel(
            isDisabling: isDisabling,
            parentVM: viewModel
        )

        vm.onSuccess = { [weak self] in
            self?.dismiss(animated: true)
            self?.is2FAEnabled = !isDisabling
            self?.updateUI(enabled: self?.is2FAEnabled ?? false)
        }

        vm.onFailure = { [weak self] in
            self?.dismiss(animated: true)
            self?.revertSwitch()
        }

        let vc = UIHostingController(
            rootView: OTPVerificationView(viewModel: vm)
        )

        vc.modalPresentationStyle = .formSheet
        present(vc, animated: true)
    }

    // MARK: - Helpers
    private func updateUI(enabled: Bool) {
        twoFASwitch.setOn(enabled, animated: true)
        twoFASwitch.isEnabled = true
        statusLabel.text = enabled ? "Enabled" : "Disabled"
        statusLabel.textColor = enabled ? .systemGreen : .systemRed
    }

    private func revertSwitch() {
        twoFASwitch.setOn(is2FAEnabled, animated: true)
        twoFASwitch.isEnabled = true
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(.init(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
