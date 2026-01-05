//
//  ResetPasswordViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 07/10/25.
//


import UIKit

class ResetPasswordViewController: BaseViewController {

    // MARK: - Outlets
    @IBOutlet weak var lblNewPassword: UILabel!
    @IBOutlet weak var viewNewPassword: UIView!
    @IBOutlet weak var txtNewPassword: UITextField!

    @IBOutlet weak var lblConfirmPassword: UILabel!
    @IBOutlet weak var viewConfirmPassword: UIView!
    @IBOutlet weak var txtConfirmPassword: UITextField!

    @IBOutlet weak var btnReset: UIButton!

    // Optional (wire if you have “eye” buttons in storyboard)
    @IBOutlet weak var btnNewPwdEye: UIButton?
    @IBOutlet weak var btnConfirmPwdEye: UIButton?

    // MARK: - Flow inputs
    var email: String!
    var otp: String!

    // MARK: - Styling (same as Login VC)
    private let focusedColor = UIColor(named: "selectedTextfieldColor")
    private let normalColor  = UIColor(named: "unselectedTextFieldColor")

    // MARK: - VM
    lazy var viewModel: ResetPasswordViewModel = {
        let vm = ResetPasswordViewModel()
        self.baseVwModel = vm
        return vm
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup delegates
        txtNewPassword.delegate = self
        txtConfirmPassword.delegate = self
        txtNewPassword.isSecureTextEntry = true
        txtConfirmPassword.isSecureTextEntry = true

        // Initial highlight state
        updateUI(for: viewNewPassword, label: lblNewPassword, isFocused: false)
        updateUI(for: viewConfirmPassword, label: lblConfirmPassword, isFocused: false)

        // Editing changed to allow live validations (optional)
        txtNewPassword.addTarget(self, action: #selector(textEditingChanged(_:)), for: .editingChanged)
        txtConfirmPassword.addTarget(self, action: #selector(textEditingChanged(_:)), for: .editingChanged)

        setupBindings()
        btnReset.isEnabled = true
    }

    private func setupBindings() {
        viewModel.onResult = { [weak self] success, message in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.btnReset.isEnabled = true
                if success {
                    let alert = UIAlertController(
                        title: "Success",
                        message: message ?? "Your password has been reset.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                        self.navigationController?.popToRootViewController(animated: true)
                    }))
                    self.present(alert, animated: true)
                } else {
                    self.showAlert("Error", message ?? "Failed to reset password.")
                }
            }
        }
    }

    // MARK: - Actions
    @IBAction func btnResetTapped(_ sender: UIButton) {
        guard let email = email, !email.isEmpty, let otp = otp, !otp.isEmpty else {
            showAlert("Error", "Missing email or token.")
            return
        }

        let newPass = txtNewPassword.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let confirm = txtConfirmPassword.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Same validation policy as Login
        if let error = Self.validatePasswords(new: newPass, confirm: confirm) {
            showAlert("Error", error)
            return
        }

        btnReset.isEnabled = false
        viewModel.reset(email: email, otp: otp, newPassword: newPass)
    }

    @IBAction func btnNewPwdEyeTapped(_ sender: UIButton) {
        guard let btn = btnNewPwdEye else { return }
        txtNewPassword.isSecureTextEntry.toggle()
        btn.setImage(UIImage(systemName: txtNewPassword.isSecureTextEntry ? "eye.slash" : "eye"), for: .normal)
    }

    @IBAction func btnConfirmPwdEyeTapped(_ sender: UIButton) {
        guard let btn = btnConfirmPwdEye else { return }
        txtConfirmPassword.isSecureTextEntry.toggle()
        btn.setImage(UIImage(systemName: txtConfirmPassword.isSecureTextEntry ? "eye.slash" : "eye"), for: .normal)
    }
    
    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }

    // MARK: - Helpers
    private func updateUI(for view: UIView, label: UILabel, isFocused: Bool) {
        let color = isFocused ? focusedColor : normalColor
        UIView.animate(withDuration: 0.25) {
            view.borderColor = color
            label.textColor = color
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }

    @objc private func textEditingChanged(_ textField: UITextField) {
        // (Optional) live enable/disable logic could go here
    }

    // MARK: - Validation (same policy as Login)
    /// ≥8 chars, must include: 1 upper, 1 lower, 1 digit, 1 special.
    static func validatePasswords(new: String, confirm: String) -> String? {
        guard !new.isEmpty else { return "Please enter a new password." }
        guard !confirm.isEmpty else { return "Please confirm your new password." }
        guard new == confirm else { return "Passwords do not match." }

        // Same strong password rules you likely used at login / signup
        let pattern = #"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\w\s]).{8,}$"#
        let ok = new.range(of: pattern, options: .regularExpression) != nil
        if !ok {
            return "Password must be at least 8 characters and include upper, lower, number, and special character."
        }
        return nil
    }
}

// MARK: - UITextFieldDelegate
extension ResetPasswordViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == txtNewPassword {
            updateUI(for: viewNewPassword, label: lblNewPassword, isFocused: true)
        } else if textField == txtConfirmPassword {
            updateUI(for: viewConfirmPassword, label: lblConfirmPassword, isFocused: true)
        }
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == txtNewPassword {
            updateUI(for: viewNewPassword, label: lblNewPassword, isFocused: false)
        } else if textField == txtConfirmPassword {
            updateUI(for: viewConfirmPassword, label: lblConfirmPassword, isFocused: false)
        }
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == txtNewPassword {
            txtConfirmPassword.becomeFirstResponder()
        } else if textField == txtConfirmPassword {
            textField.resignFirstResponder()
            btnReset.sendActions(for: .touchUpInside)
        }
        return true
    }
}
