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
    
    // MARK: - Properties
    
    private var textFields: [UITextField] = []
    lazy var viewModel: VerificationCodeViewModel = {
        let obj = VerificationCodeViewModel()
        self.baseVwModel = obj
        return obj
    }()
    
    // Define your colors here to easily change them later
    let focusedColor = UIColor(named: "selectedTextfieldColor")
    let normalColor = UIColor(named: "unselectedTextFieldColor")
    
    var email: String? // This can be passed from the previous screen

    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextFields()
        setupViewModelBindings()
        
        if let email = email {
            lblEmailInfo.text = "We've sent a verification code to\n\(email)"
        }
    }
    
    // MARK: - Setup
    
    private func setupTextFields() {
        textFields = [txtOtp1, txtOtp2, txtOtp3, txtOtp4]
        for (index, textField) in textFields.enumerated() {
            textField.delegate = self
            textField.tag = index
            textField.keyboardType = .numberPad
            
            // Set initial border style for all text fields
            textField.borderWidth = 1.0 // Or your desired width
            textField.cornerRadius = 8.0 // Or your desired radius
            updateUI(for: textField, isFocused: false)
        }
        
        // Start with the first text field active
        txtOtp1.becomeFirstResponder()
    }
    
    private func setupViewModelBindings() {
        viewModel.onValidationResult = { [weak self] isValid, errorMessage in
            if isValid {
                print("OTP Verified Successfully!")
                 let emailVerifiedVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "EmailVerifiedViewController") as! EmailVerifiedViewController
                self?.navigationController?.pushViewController(emailVerifiedVC, transitionType: .fade)
            } else {
                if let message = errorMessage {
                    self?.showAlert(message: message)
                }
            }
        }
        
        viewModel.onResendResult = { [weak self] message in
            self?.showAlert(title: "Success", message: message)
        }
    }

    // MARK: - Actions
    
    @IBAction func btnConfirmTapped(_ sender: UIButton) {
        let enteredOTP = textFields.compactMap { $0.text }.joined()
        viewModel.validate(enteredOTP: enteredOTP)
    }
    
    @IBAction func btnResendTapped(_ sender: UIButton) {
        viewModel.resendCode()
    }
    
    @IBAction func btnSignUpTapped(_ sender: UIButton) {
        // 1. Get the array of all view controllers currently in the navigation stack.
        guard let viewControllers = self.navigationController?.viewControllers else { return }
        
        // 2. Loop through the array to find the SignUpViewController.
        for vc in viewControllers {
            if vc is SignUpViewController {
                // 3. If we find it, pop back to that specific view controller.
                self.navigationController?.popToViewController(vc, transitionType: .fade, duration: 0.03)
                break // Exit the loop once we've found it
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Updates the border color for a given text field.
    private func updateUI(for textField: UITextField, isFocused: Bool) {
        let color = isFocused ? focusedColor : normalColor
        
        // Animate the color change for a smooth effect
        UIView.animate(withDuration: 0.3) {
            textField.superview?.borderColor = color
        }
    }
    
    private func showAlert(title: String = "Error", message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

// MARK: - UITextFieldDelegate

extension VerificationCodeViewController: UITextFieldDelegate {
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Set the border color to focused when the user taps on a field.
        updateUI(for: textField, isFocused: true)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        // Set the border color back to normal when the user leaves a field.
        updateUI(for: textField, isFocused: false)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        if string.isEmpty { // Handle backspace
            textField.text = ""
            if textField.tag > 0 {
                textFields[textField.tag - 1].becomeFirstResponder()
            }
            return false
        }
        
        if let text = textField.text, text.count > 0 {
             if textField.tag < textFields.count - 1 {
                 textFields[textField.tag + 1].becomeFirstResponder()
                 textFields[textField.tag + 1].text = string
             } else {
                 textField.text = string
                 textField.resignFirstResponder()
             }
             return false
         }
        
        if string.count == 1 { // Handle new character entry
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
