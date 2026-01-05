//
//  ForgotPasswordEmailViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 07/10/25.
//


//
//  ForgotPasswordEmailViewController.swift
//  CalmTrade
//

import UIKit

final class ForgotPasswordEmailViewController: BaseViewController {

    // MARK: - Outlets
    @IBOutlet weak var lblEmail: UILabel!
    @IBOutlet weak var viewEmail: UIView!
    @IBOutlet weak var txtEmail: UITextField!
    @IBOutlet weak var btnContinue: UIButton!

    // MARK: - Styling (reuse login colors)
    private let focusedColor = UIColor(named: "selectedTextfieldColor")
    private let normalColor  = UIColor(named: "unselectedTextFieldColor")

    // MARK: - VM
    lazy var viewModel: ForgotPasswordEmailViewModel = {
        let vm = ForgotPasswordEmailViewModel()
        self.baseVwModel = vm
        return vm
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        txtEmail.delegate = self
        updateUI(for: viewEmail, label: lblEmail, isFocused: false)
        wireUpVM()
    }

    private func wireUpVM() {
        viewModel.onLoading = { [weak self] isLoading in
            DispatchQueue.main.async {
                self?.btnContinue.isEnabled = !isLoading
                //            isLoading ? self?.startLoading() : self?.stopLoading()
            }
        }
        viewModel.onError = { [weak self] message in
            DispatchQueue.main.async {
                self?.showAlert(message: message)
            }
        }
        viewModel.onSuccess = { [weak self] message in
            guard let self = self else { return }
            // Move to OTP screen (you’ll wire this VC next)
            DispatchQueue.main.async {
                let vc = UIStoryboard(name: "Main", bundle: nil)
                    .instantiateViewController(withIdentifier: "ForgotPasswordOTPViewController") as! ForgotPasswordOTPViewController
                vc.passedEmail = self.viewModel.email
                vc.infoMessage = message   // “We’ve sent a code to ...”
                self.navigationController?.pushViewController(vc, transitionType: .fade)
            }
        }
    }

    // MARK: - Actions
    @IBAction func btnContinueTapped(_ sender: UIButton) {
        viewModel.email = txtEmail.text ?? ""
        view.endEditing(true)
        viewModel.submit()
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
}

// MARK: - UITextFieldDelegate
extension ForgotPasswordEmailViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == txtEmail { updateUI(for: viewEmail, label: lblEmail, isFocused: true) }
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == txtEmail { updateUI(for: viewEmail, label: lblEmail, isFocused: false) }
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == txtEmail {
            textField.resignFirstResponder()
            btnContinue.sendActions(for: .touchUpInside)
        }
        return true
    }
}
