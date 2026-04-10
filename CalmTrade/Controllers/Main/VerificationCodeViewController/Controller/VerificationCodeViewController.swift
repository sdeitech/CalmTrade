//
//  VerificationCodeViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 26/08/25.
//

import UIKit

class VerificationCodeViewController: BaseViewController {

    // MARK: - Outlets
    @IBOutlet weak var txtOtp1: UITextField!
    @IBOutlet weak var txtOtp2: UITextField!
    @IBOutlet weak var txtOtp3: UITextField!
    @IBOutlet weak var txtOtp4: UITextField!
    @IBOutlet weak var lblEmailInfo: UILabel!
    @IBOutlet weak var btnConfirm: UIButton!

    // MARK: - Properties
    private var textFields: [UITextField] = []
    lazy var viewModel: VerificationCodeViewModel = {
        let obj = VerificationCodeViewModel()
        self.baseVwModel = obj
        return obj
    }()

    let focusedColor = UIColor(named: "selectedTextfieldColor")
    let normalColor  = UIColor(named: "unselectedTextFieldColor")

    /// Pass this from the previous screen (EmailVerificationViewController)
    var email: String?

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextFields()
        setupViewModelBindings()

        if let email = email, !email.isEmpty {
            lblEmailInfo.text = "We've sent a verification code to\n\(email)"
        } else {
            lblEmailInfo.text = "Enter the verification code sent to your email"
        }
    }

    // MARK: - Setup
    private func setupTextFields() {
        textFields = [txtOtp1, txtOtp2, txtOtp3, txtOtp4]
        for (index, textField) in textFields.enumerated() {
            textField.delegate = self
            textField.tag = index
            textField.keyboardType = .numberPad
            textField.borderWidth  = 1.0
            textField.cornerRadius = 8.0
            updateUI(for: textField, isFocused: false)
            textField.addTarget(self, action: #selector(textFieldEditingChanged(_:)), for: .editingChanged)
        }
        txtOtp1.becomeFirstResponder()
    }

    private func setupViewModelBindings() {
        viewModel.onValidationResult = { [weak self] isValid, errorMessage in
            guard let self = self else { return }
            self.btnConfirm.isEnabled = true
            if isValid {
                UserDefaults.standard.set(LoginHandler.email.rawValue, forKey: kLoginHandler)
                let vc = UIStoryboard(name: "Main", bundle: nil)
                    .instantiateViewController(withIdentifier: "EmailVerifiedViewController") as! EmailVerifiedViewController
                self.navigationController?.pushViewController(vc, transitionType: .fade)
            } else {
                if let message = errorMessage { self.showAlert(message: message) }
            }
        }

        viewModel.onResendResult = { [weak self] message in
            self?.showAlert(title: "Success", message: message)
        }
    }

    // MARK: - Actions
    @IBAction func btnConfirmTapped(_ sender: UIButton) {
        let enteredOTP = textFields.compactMap { $0.text }.joined()
        btnConfirm.isEnabled = false
        viewModel.verify(email: email, enteredOTP: enteredOTP)
    }

    @IBAction func btnResendTapped(_ sender: UIButton) {
        viewModel.resendCode(to: email)
    }

    @IBAction func btnSignUpTapped(_ sender: UIButton) {
        guard let vcs = navigationController?.viewControllers else { return }
        for vc in vcs where vc is SignUpViewController {
            navigationController?.popToViewController(vc, transitionType: .fade, duration: 0.03)
            break
        }
    }

    // MARK: - Helpers
    private func updateUI(for textField: UITextField, isFocused: Bool) {
        let color = isFocused ? focusedColor : normalColor
        UIView.animate(withDuration: 0.25) {
            textField.superview?.borderColor = color
        }
    }

    private func showAlert(title: String = "Error", message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func textFieldEditingChanged(_ textField: UITextField) {
        guard let text = textField.text else { return }
        // Keep only single character
        if text.count > 1 {
            textField.text = String(text.prefix(1))
        }
        // Auto-advance
        if text.count == 1 {
            if textField.tag < textFields.count - 1 {
                textFields[textField.tag + 1].becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
        }
    }
}

// MARK: - UITextFieldDelegate
extension VerificationCodeViewController: UITextFieldDelegate {

    func textFieldDidBeginEditing(_ textField: UITextField) {
        updateUI(for: textField, isFocused: true)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        updateUI(for: textField, isFocused: false)
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {

        // Handle backspace
        if string.isEmpty {
            textField.text = ""
            if textField.tag > 0 {
                textFields[textField.tag - 1].becomeFirstResponder()
            }
            return false
        }

        // If already has a char, move forward and place it
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

        // Normal single char
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
