//
//  ChangeEmailOTPViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/01/26.
//


import UIKit
import KRProgressHUD

final class ChangeEmailOTPViewController: BaseViewController {

    // MARK: - Outlets

    @IBOutlet weak var txtOtp1: UITextField!
    @IBOutlet weak var txtOtp2: UITextField!
    @IBOutlet weak var txtOtp3: UITextField!
    @IBOutlet weak var txtOtp4: UITextField!

    @IBOutlet weak var btnContinue: UIButton!
    @IBOutlet weak var btnResend: UIButton!
    @IBOutlet weak var lblResendTimer: UILabel!

    // MARK: - Properties

    private var textFields: [UITextField] = []

    let focusedColor = UIColor(named: "selectedTextfieldColor")
    let normalColor  = UIColor(named: "unselectedTextFieldColor")

    let viewModel = ChangeEmailOTPViewModel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextFields()
        bindViewModel()

        lblResendTimer.text = "in 35 s"
        btnResend.isEnabled = false
        viewModel.beginCountdown(seconds: 35)
    }

    // MARK: - Setup

    private func setupTextFields() {
        textFields = [txtOtp1, txtOtp2, txtOtp3, txtOtp4]

        for (index, tf) in textFields.enumerated() {
            tf.delegate = self
            tf.tag = index
            tf.keyboardType = .numberPad
            tf.borderWidth = 1
            tf.cornerRadius = 8
            updateUI(for: tf, isFocused: false)
            tf.addTarget(self,
                         action: #selector(textFieldEditingChanged(_:)),
                         for: .editingChanged)
        }

        txtOtp1.becomeFirstResponder()
    }

    // MARK: - ViewModel Binding

    private func bindViewModel() {
        viewModel.onLoading = { loading in
            loading ? LoaderManager.shared.show() : LoaderManager.shared.hide()
        }

        viewModel.onError = { [weak self] message in
            self?.showAlert(message: message)
        }

        viewModel.onSuccess = { [weak self] newEmail in
            self?.showSuccessAndPop()
        }

        viewModel.onResent = { [weak self] in
            self?.viewModel.beginCountdown(seconds: 35)
        }

        // Countdown UI (MATCH Forgot Password)
        viewModel.onResendTick = { [weak self] seconds in
            self?.lblResendTimer.text = seconds > 0 ? "in \(seconds) s" : "in 0 s"
        }

        viewModel.onResendAvailability = { [weak self] enabled in
            self?.btnResend.isEnabled = enabled
        }
    }

    // MARK: - Actions

    @IBAction func btnContinueTapped(_ sender: UIButton) {
        view.endEditing(true)
        viewModel.verifyOTP(collectOTP())
    }

    @IBAction func btnResendTapped(_ sender: UIButton) {
        viewModel.resendOTP()
    }
    
    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }

    // MARK: - Helpers

    private func collectOTP() -> String {
        textFields.compactMap { $0.text }.joined()
    }

    private func updateUI(for textField: UITextField, isFocused: Bool) {
        let color = isFocused ? focusedColor : normalColor
        UIView.animate(withDuration: 0.25) {
            textField.superview?.borderColor = color
        }
    }

    private func showSuccessAndPop() {
        let alert = UIAlertController(
            title: nil,
            message: "Email updated successfully",
            preferredStyle: .alert
        )

        let action = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self = self else { return }

            // 1️⃣ Check if TabBarController already exists in stack
            if let tabBarVC = self.navigationController?
                .viewControllers
                .first(where: { $0 is TabbarController }) {

                self.navigationController?.popToViewController(tabBarVC)
                return
            }

            // 2️⃣ Otherwise, push a new TabBarController
            let tabBarVC = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil)
                .instantiateViewController(withIdentifier: "TabbarController") as! TabbarController

            self.navigationController?.setViewControllers([tabBarVC], animated: true)
        }

        alert.addAction(action)
        present(alert, animated: true)
    }


    @objc private func textFieldEditingChanged(_ textField: UITextField) {
        guard let text = textField.text else { return }

        if text.count > 1 {
            textField.text = String(text.prefix(1))
        }

        if text.count == 1 {
            if textField.tag < textFields.count - 1 {
                textFields[textField.tag + 1].becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
        }
    }
}

extension ChangeEmailOTPViewController: UITextFieldDelegate {

    func textFieldDidBeginEditing(_ textField: UITextField) {
        updateUI(for: textField, isFocused: true)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        updateUI(for: textField, isFocused: false)
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {

        // Backspace
        if string.isEmpty {
            textField.text = ""
            if textField.tag > 0 {
                textFields[textField.tag - 1].becomeFirstResponder()
            }
            return false
        }

        // Replace existing
        if let current = textField.text, current.count > 0 {
            if textField.tag < textFields.count - 1 {
                textFields[textField.tag + 1].text = string
                textFields[textField.tag + 1].becomeFirstResponder()
            } else {
                textField.text = string
                textField.resignFirstResponder()
            }
            return false
        }

        // Normal input
        if string.count == 1 {
            textField.text = string
            if textField.tag < textFields.count - 1 {
                textFields[textField.tag + 1].becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
            return false
        }

        return true
    }
}
