//
//  ChangePasswordViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 05/01/26.
//


import UIKit
import KRProgressHUD

final class ChangePasswordViewController: BaseViewController {

    // MARK: - Outlets

    @IBOutlet weak var lblCurrent: UILabel!
    @IBOutlet weak var viewCurrent: UIView!
    @IBOutlet weak var txtCurrent: UITextField!
    @IBOutlet weak var btnCurrentEye: UIButton!

    @IBOutlet weak var lblNew: UILabel!
    @IBOutlet weak var viewNew: UIView!
    @IBOutlet weak var txtNew: UITextField!
    @IBOutlet weak var btnNewEye: UIButton!

    @IBOutlet weak var lblConfirm: UILabel!
    @IBOutlet weak var viewConfirm: UIView!
    @IBOutlet weak var txtConfirm: UITextField!
    @IBOutlet weak var btnConfirmEye: UIButton!

    // MARK: - Properties

    private let focusedColor = UIColor(named: "selectedTextfieldColor")
    private let normalColor = UIColor(named: "unselectedTextFieldColor")

    private lazy var viewModel = ChangePasswordViewModel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        [txtCurrent, txtNew, txtConfirm].forEach {
            $0?.delegate = self
            $0?.isSecureTextEntry = true
        }

        updateUI(for: viewCurrent, label: lblCurrent, isFocused: false)
        updateUI(for: viewNew, label: lblNew, isFocused: false)
        updateUI(for: viewConfirm, label: lblConfirm, isFocused: false)
    }

    // MARK: - Actions

    @IBAction func btnUpdatePasswordTapped(_ sender: UIButton) {

        viewModel.currentPassword = txtCurrent.text ?? ""
        viewModel.newPassword = txtNew.text ?? ""
        viewModel.confirmPassword = txtConfirm.text ?? ""

        let (isValid, error) = viewModel.validate()
        guard isValid else {
            showAlert(message: error ?? "Invalid input")
            return
        }

        sender.isEnabled = false
        KRProgressHUD.show()

        viewModel.submit { [weak self] success, message in
            guard let self else { return }
            sender.isEnabled = true
            KRProgressHUD.dismiss()

            if success {
                self.navigationController?.popViewController()
            } else {
                self.showAlert(message: message ?? "Failed to update password.")
            }
        }
    }

    // MARK: - Eye Buttons

    @IBAction func btnCurrentEyeTapped(_ sender: UIButton) {
        toggleEye(textField: txtCurrent, button: sender)
    }

    @IBAction func btnNewEyeTapped(_ sender: UIButton) {
        toggleEye(textField: txtNew, button: sender)
    }

    @IBAction func btnConfirmEyeTapped(_ sender: UIButton) {
        toggleEye(textField: txtConfirm, button: sender)
    }
    
    @IBAction func btnBackTapped(_ sender: UIButton) {
        navigationController?.popViewController()
    }

    private func toggleEye(textField: UITextField, button: UIButton) {
        textField.isSecureTextEntry.toggle()
        let image = textField.isSecureTextEntry ? "eye.slash" : "eye"
        button.setImage(UIImage(systemName: image), for: .normal)
    }

    // MARK: - UI Helper

    func updateUI(for view: UIView, label: UILabel, isFocused: Bool) {
        let color = isFocused ? focusedColor : normalColor
        UIView.animate(withDuration: 0.25) {
            view.borderColor = color
            label.textColor = color
        }
    }
}

extension ChangePasswordViewController: UITextFieldDelegate {

    func textFieldDidBeginEditing(_ textField: UITextField) {
        switch textField {
        case txtCurrent:
            updateUI(for: viewCurrent, label: lblCurrent, isFocused: true)
        case txtNew:
            updateUI(for: viewNew, label: lblNew, isFocused: true)
        case txtConfirm:
            updateUI(for: viewConfirm, label: lblConfirm, isFocused: true)
        default: break
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        switch textField {
        case txtCurrent:
            updateUI(for: viewCurrent, label: lblCurrent, isFocused: false)
        case txtNew:
            updateUI(for: viewNew, label: lblNew, isFocused: false)
        case txtConfirm:
            updateUI(for: viewConfirm, label: lblConfirm, isFocused: false)
        default: break
        }
    }
}
