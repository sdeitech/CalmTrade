//
//  StartSessionViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/12/25.
//

import UIKit
import KRProgressHUD

final class StartSessionViewController: UIViewController {

    // MARK: - IBOutlets

    @IBOutlet weak var tradeLossField: UITextField!
    @IBOutlet weak var sessionLossField: UITextField!

    @IBOutlet weak var lblTradeLoss: UILabel!
    @IBOutlet weak var lblSessionLoss: UILabel!

    @IBOutlet weak var viewTradeLoss: UIView!
    @IBOutlet weak var viewSessionLoss: UIView!

    @IBOutlet weak var useDefaultButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    
    @IBOutlet weak var lblDate: UILabel!

    // MARK: - Dependencies

    var viewModel: StartSessionViewModel = StartSessionViewModel()
    var showsBackButton: Bool = false

    // MARK: - UI State

    private let focusedColor = UIColor(named: "selectedTextfieldColor")
    private let normalColor = UIColor(named: "unselectedTextFieldColor")

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let f = DateFormatter()
        f.dateStyle = .medium
        lblDate.text = f.string(from: Date())

        backButton.isHidden = !showsBackButton

        tradeLossField.delegate = self
        sessionLossField.delegate = self

        bind()
        viewModel.viewDidLoad()

        // Initial UI state
        updateUI(for: viewTradeLoss, label: lblTradeLoss, isFocused: false)
        updateUI(for: viewSessionLoss, label: lblSessionLoss, isFocused: false)
    }

    // MARK: - Bindings

    private func bind() {

        viewModel.onDefaultsApplied = { [weak self] trade, session in
            self?.tradeLossField.text = trade
            self?.sessionLossField.text = session
        }

        viewModel.onUseDefaultEnabled = { [weak self] enabled in
            self?.useDefaultButton.isEnabled = enabled
            self?.useDefaultButton.alpha = enabled ? 1.0 : 0.5
        }

        viewModel.onSaveEnabled = { [weak self] enabled in
            self?.saveButton.isEnabled = enabled
            self?.saveButton.alpha = enabled ? 1.0 : 0.5
        }

        viewModel.onLoading = { loading in
            loading ? LoaderManager.shared.show()
                    : LoaderManager.shared.hide()
        }

        viewModel.onSuccess = { [weak self] in
            LoaderManager.shared.hide()
            self?.navigationController?.popViewController()
        }

        viewModel.onError = { [weak self] message in
            LoaderManager.shared.hide()
            self?.showAlert(message)
        }
    }

    // MARK: - Actions

    @IBAction func tradeLossChanged(_ sender: UITextField) {
        viewModel.tradeLossChanged(sender.text ?? "")
    }

    @IBAction func sessionLossChanged(_ sender: UITextField) {
        viewModel.sessionLossChanged(sender.text ?? "")
    }

    @IBAction func useDefaultsTapped() {
        viewModel.useDefaultsTapped()
    }

    @IBAction func saveTapped() {
        viewModel.saveTapped()
    }

    @IBAction func backTapped() {
        navigationController?.popViewController()
    }

    // MARK: - UI Helpers

    private func updateUI(for view: UIView, label: UILabel, isFocused: Bool) {
        let color = isFocused ? focusedColor : normalColor
        UIView.animate(withDuration: 0.25) {
            view.borderColor = color
            label.textColor = color
        }
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension StartSessionViewController: UITextFieldDelegate {

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField === tradeLossField {
            updateUI(for: viewTradeLoss, label: lblTradeLoss, isFocused: true)
        } else if textField === sessionLossField {
            updateUI(for: viewSessionLoss, label: lblSessionLoss, isFocused: true)
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField === tradeLossField {
            updateUI(for: viewTradeLoss, label: lblTradeLoss, isFocused: false)
        } else if textField === sessionLossField {
            updateUI(for: viewSessionLoss, label: lblSessionLoss, isFocused: false)
        }
    }
}
