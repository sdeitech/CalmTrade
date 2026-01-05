//
//  ForgotPasswordOTPViewController.swift
//  CalmTrade
//

import UIKit

final class ForgotPasswordOTPViewController: BaseViewController {

    // MARK: - Outlets (your storyboard setup)
    @IBOutlet weak var txtOtp1: UITextField!
    @IBOutlet weak var txtOtp2: UITextField!
    @IBOutlet weak var txtOtp3: UITextField!
    @IBOutlet weak var txtOtp4: UITextField!
    @IBOutlet weak var lblEmailInfo: UILabel!
    @IBOutlet weak var btnConfirm: UIButton!

    // NEW: Resend UI
    @IBOutlet weak var btnResend: UIButton!
    @IBOutlet weak var lblResendTimer: UILabel!  // shows "in XX s" beside button

    // MARK: - Properties
    private var textFields: [UITextField] = []

    lazy var viewModel: ForgotPasswordOTPViewModel = {
        let vm = ForgotPasswordOTPViewModel()
        self.baseVwModel = vm
        return vm
    }()

    let focusedColor = UIColor(named: "selectedTextfieldColor")
    let normalColor  = UIColor(named: "unselectedTextFieldColor")

    var passedEmail: String?
    var infoMessage: String?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextFields()
        wireUpVM()

        if let info = infoMessage, !info.isEmpty {
            lblEmailInfo.text = info
        } else if let email = passedEmail, !email.isEmpty {
            lblEmailInfo.text = "We've sent a verification code to\n\(email)"
        } else {
            lblEmailInfo.text = "Enter the verification code sent to your email"
        }

        // Start initial countdown at 35s
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
            tf.borderWidth  = 1.0
            tf.cornerRadius = 8.0
            updateUI(for: tf, isFocused: false)
            tf.addTarget(self, action: #selector(textFieldEditingChanged(_:)), for: .editingChanged)
        }
        txtOtp1.becomeFirstResponder()
    }

    private func wireUpVM() {
        viewModel.onLoading = { [weak self] loading in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.btnConfirm.isEnabled = !loading
                // loading ? self.startLoading() : self.stopLoading()
            }
        }
        viewModel.onError = { [weak self] msg in
            DispatchQueue.main.async { self?.showAlert(message: msg) }
        }

        // 🔑 Now receives the backend token from the ViewModel
        viewModel.onVerified = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let vc = UIStoryboard(name: "Main", bundle: nil)
                    .instantiateViewController(withIdentifier: "ResetPasswordViewController") as! ResetPasswordViewController
                vc.email = self.passedEmail ?? ""
                vc.otp = self.collectOTP()                     // <-- CHANGED: pass backend token, not the OTP
                self.navigationController?.pushViewController(vc, transitionType: .fade)
            }
        }

        viewModel.onResent = { [weak self] msg in
            DispatchQueue.main.async { self?.showAlert(title: "Success", message: msg) }
        }

        // Countdown bindings
        viewModel.onResendTick = { [weak self] seconds in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.lblResendTimer.text = seconds > 0 ? "in \(seconds) s" : "in 0 s"
            }
        }
        viewModel.onResendAvailability = { [weak self] enabled in
            DispatchQueue.main.async { self?.btnResend.isEnabled = enabled }
        }
    }

    // MARK: - Actions
    @IBAction func btnConfirmTapped(_ sender: UIButton) {
        view.endEditing(true)
        viewModel.verify(email: passedEmail, enteredOTP: collectOTP())
    }

    @IBAction func btnResendTapped(_ sender: UIButton) {
        viewModel.resendCode(to: passedEmail)
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

    private func showAlert(title: String = "Error", message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func textFieldEditingChanged(_ textField: UITextField) {
        guard let text = textField.text else { return }
        if text.count > 1 { textField.text = String(text.prefix(1)) }
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
extension ForgotPasswordOTPViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) { updateUI(for: textField, isFocused: true) }
    func textFieldDidEndEditing(_ textField: UITextField) { updateUI(for: textField, isFocused: false) }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        if string.isEmpty {
            textField.text = ""
            if textField.tag > 0 { textFields[textField.tag - 1].becomeFirstResponder() }
            return false
        }
        if let cur = textField.text, cur.count > 0 {
            if textField.tag < textFields.count - 1 {
                textFields[textField.tag + 1].text = string
                textFields[textField.tag + 1].becomeFirstResponder()
            } else {
                textField.text = string
                textField.resignFirstResponder()
            }
            return false
        }
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
