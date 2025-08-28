//
//  SignUpViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/08/25.
//

import UIKit

class SignUpViewController: BaseViewController {
    
    // MARK: - Outlets
    // --- Name UI Elements ---
    @IBOutlet weak var lblName: UILabel!
    @IBOutlet weak var viewName: UIView!
    @IBOutlet weak var txtName: UITextField!
    
    // --- Email UI Elements ---
    @IBOutlet weak var lblEmail: UILabel!
    @IBOutlet weak var viewEmail: UIView!
    @IBOutlet weak var txtEmail: UITextField!
    
    // --- Phone UI Elements ---
    @IBOutlet weak var lblPhone: UILabel!
    @IBOutlet weak var viewPhone: UIView!
    @IBOutlet weak var txtPhone: UITextField!
    
    // --- Password UI Elements ---
    @IBOutlet weak var lblPassword: UILabel!
    @IBOutlet weak var viewPassword: UIView!
    @IBOutlet weak var txtPassword: UITextField!
    @IBOutlet weak var btnPasswordEye: UIButton!
    
    @IBOutlet weak var lblTerms: UILabel!
    @IBOutlet weak var btnCheckbox: UIButton!
    
    
    // MARK: - Properties
    
    lazy var viewModel: SignUpViewModel = {
        let obj = SignUpViewModel()
        self.baseVwModel = obj
        return obj
    }()
    
    //MARK: - App Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the text field delegates to self
        txtName.delegate = self
        txtEmail.delegate = self
        txtPhone.delegate = self
        txtPassword.delegate = self
        
        // Set initial state for the UI elements
        updateUI(for: viewName, label: lblName, isFocused: false)
        updateUI(for: viewEmail, label: lblEmail, isFocused: false)
        updateUI(for: viewPhone, label: lblPhone, isFocused: false)
        updateUI(for: viewPassword, label: lblPassword, isFocused: false)
        
        viewModel.setupTappableLabel(label: lblTerms, action: #selector(handleLabelTap(_:)))
    }
    
    // MARK: - Actions
    
    @IBAction func btnPasswordEyeTapped(_ sender: UIButton) {
        // Toggle the secure text entry state
        txtPassword.isSecureTextEntry.toggle()
        
        // Change the button icon based on the state
        if txtPassword.isSecureTextEntry {
            // Use SF Symbols for modern icons
            btnPasswordEye.setImage(UIImage(systemName: "eye.slash"), for: .normal)
        } else {
            btnPasswordEye.setImage(UIImage(systemName: "eye"), for: .normal)
        }
    }
    
    @IBAction func btnCheckboxTapped(_ sender: UIButton) {
        viewModel.isCheckboxSelected.toggle()
        if viewModel.isCheckboxSelected {
            btnCheckbox.setImage(viewModel.selectedImage, for: .normal)
        } else {
            btnCheckbox.setImage(viewModel.unselectedImage, for: .normal)
        }
    }
    
    @IBAction func btnLoginTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func btnSignUpTapped(_ sender: UIButton) {
        let fullName = txtName.text
        let email = txtEmail.text
        let phone = txtPhone.text
        let password = txtPassword.text
        
        // 1. Validate the form first.
        let validationResult = viewModel.validate(fullName: fullName, email: email, phoneNumber: phone, password: password)
        
        if !validationResult.isValid {
            showAlert(message: validationResult.error ?? "An unknown error occurred.")
            return
        }
        
        // 2. Call the ViewModel to create the user and send the email.
        viewModel.createUser(email: email!, password: password!, fullName: fullName!) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    // --- SUCCESS ---
                    // Navigate to the email verification screen.
                    self?.navigateToVerificationScreen()
                } else {
                    // --- FAILURE ---
                    // Show an alert with the error from Firebase.
                    self?.showAlert(message: error?.localizedDescription ?? "An unknown error occurred.")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func navigateToVerificationScreen() {
        
        let verificationVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "EmailVerificationViewController") as! EmailVerificationViewController
        self.navigationController?.pushViewController(verificationVC, animated: true)
    }
    
    /// Updates the border and label color for a text field's container.
    func updateUI(for view: UIView, label: UILabel, isFocused: Bool) {
        let color = isFocused ? viewModel.focusedColor : viewModel.normalColor
        
        // Animate the color changes for a smoother effect
        UIView.animate(withDuration: 0.3) {
            view.borderColor = color
            label.textColor = color
        }
    }
    
    @objc func handleLabelTap(_ gesture: UITapGestureRecognizer) {
        guard let label = gesture.view as? UILabel,
              let attributedText = label.attributedText else { return }

        let fullText = attributedText.string
        let tapLocation = gesture.location(in: label)

        // Find the character index at the tap location
        let characterIndex = viewModel.characterIndex(for: tapLocation, in: label)

        // Check if the tap was on "Terms & Conditions"
        if let termsRange = fullText.range(of: "Terms & Conditions"),
           NSRange(termsRange, in: fullText).contains(characterIndex ?? 0) {
            
            print("Tapped on Terms & Conditions")
            // Action: Open the Terms & Conditions URL
            viewModel.openURL(urlString: "https://www.example.com/terms", in: self)
        }

        // Check if the tap was on "Data Privacy Policy"
        if let policyRange = fullText.range(of: "Data Privacy Policy"),
           NSRange(policyRange, in: fullText).contains(characterIndex ?? 0) {
            
            print("Tapped on Data Privacy Policy")
            // Action: Open the Data Privacy Policy URL
            viewModel.openURL(urlString: "https://www.example.com/privacy", in: self)
        }
    }
}

// MARK: - UITextFieldDelegate

extension SignUpViewController: UITextFieldDelegate {
    
    /// This method is called when a user taps on a text field.
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == txtName {
            updateUI(for: viewName, label: lblName, isFocused: true)
        } else if textField == txtEmail {
            updateUI(for: viewEmail, label: lblEmail, isFocused: true)
        } else if textField == txtPhone {
            updateUI(for: viewPhone, label: lblPhone, isFocused: true)
        } else if textField == txtPassword {
            updateUI(for: viewPassword, label: lblPassword, isFocused: true)
        }
    }
    
    /// This method is called when a user taps away from a text field.
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == txtName {
            updateUI(for: viewName, label: lblName, isFocused: false)
        } else if textField == txtEmail {
            updateUI(for: viewEmail, label: lblEmail, isFocused: false)
        } else if textField == txtPhone {
            updateUI(for: viewPhone, label: lblPhone, isFocused: false)
        } else if textField == txtPassword {
            updateUI(for: viewPassword, label: lblPassword, isFocused: false)
        }
    }
}
