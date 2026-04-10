//
//  ChangeEmailViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/01/26.
//


import UIKit
import KRProgressHUD

final class ChangeEmailViewController: BaseViewController {

    // MARK: - Outlets

    @IBOutlet weak var lblOldEmail: UILabel!
    @IBOutlet weak var viewOldEmail: UIView!
    @IBOutlet weak var txtOldEmail: UITextField!

    @IBOutlet weak var lblNewEmail: UILabel!
    @IBOutlet weak var viewNewEmail: UIView!
    @IBOutlet weak var txtNewEmail: UITextField!

    @IBOutlet weak var lblPassword: UILabel!
    @IBOutlet weak var viewPassword: UIView!
    @IBOutlet weak var txtPassword: UITextField!
    @IBOutlet weak var btnPasswordEye: UIButton!

    @IBOutlet weak var btnUpdate: UIButton!

    // MARK: - UI Colors (MATCH ChangePassword)

    private let focusedColor = UIColor(named: "selectedTextfieldColor")
    private let normalColor  = UIColor(named: "unselectedTextFieldColor")

    // MARK: - VM

    private let viewModel = ChangeEmailViewModel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
    }

    // MARK: - Setup

    private func setupUI() {
        [txtOldEmail, txtNewEmail, txtPassword].forEach {
            $0?.delegate = self
        }

        txtPassword.isSecureTextEntry = true

        updateUI(for: viewOldEmail, label: lblOldEmail, isFocused: false)
        updateUI(for: viewNewEmail, label: lblNewEmail, isFocused: false)
        updateUI(for: viewPassword, label: lblPassword, isFocused: false)
    }

    private func bindViewModel() {
        viewModel.onLoading = { isLoading in
            isLoading ? LoaderManager.shared.show() : LoaderManager.shared.hide()
        }

        viewModel.onError = { [weak self] message in
            self?.showAlert(message: message)
        }

        viewModel.onOTPSent = { [weak self] oldEmail, newEmail in
            self?.navigateToOTP(oldEmail: oldEmail, newEmail: newEmail)
        }
    }

    // MARK: - Actions

    @IBAction func btnUpdateTapped(_ sender: UIButton) {
        let oldEmail = txtOldEmail.text ?? ""
        let newEmail = txtNewEmail.text ?? ""
        let password = txtPassword.text ?? ""

        guard viewModel.validate(
            oldEmail: oldEmail,
            newEmail: newEmail,
            password: password
        ) else { return }

        sender.isEnabled = false
        viewModel.requestEmailChange(
            oldEmail: oldEmail,
            newEmail: newEmail,
            password: password
        )
        sender.isEnabled = true
    }

    @IBAction func btnPasswordEyeTapped(_ sender: UIButton) {
        toggleEye(textField: txtPassword, button: sender)
    }
    
    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }

    // MARK: - Helpers

    private func toggleEye(textField: UITextField, button: UIButton) {
        textField.isSecureTextEntry.toggle()
        let image = textField.isSecureTextEntry ? "eye.slash" : "eye"
        button.setImage(UIImage(systemName: image), for: .normal)
    }

    private func navigateToOTP(oldEmail: String, newEmail: String) {
        let vc = storyboard!.instantiateViewController(
            withIdentifier: "ChangeEmailOTPViewController"
        ) as! ChangeEmailOTPViewController

        vc.viewModel.configure(oldEmail: oldEmail, newEmail: newEmail)
        navigationController?.pushViewController(vc)
    }

    // MARK: - UI Helper (SAME AS ChangePassword)

    func updateUI(for view: UIView, label: UILabel, isFocused: Bool) {
        let color = isFocused ? focusedColor : normalColor
        UIView.animate(withDuration: 0.25) {
            view.borderColor = color
            label.textColor = color
        }
    }
}


extension ChangeEmailViewController: UITextFieldDelegate {

    func textFieldDidBeginEditing(_ textField: UITextField) {
        switch textField {
        case txtOldEmail:
            updateUI(for: viewOldEmail, label: lblOldEmail, isFocused: true)
        case txtNewEmail:
            updateUI(for: viewNewEmail, label: lblNewEmail, isFocused: true)
        case txtPassword:
            updateUI(for: viewPassword, label: lblPassword, isFocused: true)
        default:
            break
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        switch textField {
        case txtOldEmail:
            updateUI(for: viewOldEmail, label: lblOldEmail, isFocused: false)
        case txtNewEmail:
            updateUI(for: viewNewEmail, label: lblNewEmail, isFocused: false)
        case txtPassword:
            updateUI(for: viewPassword, label: lblPassword, isFocused: false)
        default:
            break
        }
    }
}

