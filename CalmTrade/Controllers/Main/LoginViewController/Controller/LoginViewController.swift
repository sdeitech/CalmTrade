//
//  LoginViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/08/25.
//

import UIKit
import GoogleSignIn
import FirebaseAuth

class LoginViewController: BaseViewController {
    
    // MARK: - Outlets
    
    // --- Email UI Elements ---
    @IBOutlet weak var lblEmail: UILabel!
    @IBOutlet weak var viewEmail: UIView!
    @IBOutlet weak var txtEmail: UITextField!
    
    // --- Password UI Elements ---
    @IBOutlet weak var lblPassword: UILabel!
    @IBOutlet weak var viewPassword: UIView!
    @IBOutlet weak var txtPassword: UITextField!
    @IBOutlet weak var btnPasswordEye: UIButton!
    
    // MARK: - Properties
    
    // Define your colors here to easily change them later
    let focusedColor = UIColor(named: "selectedTextfieldColor")
    let normalColor = UIColor(named: "unselectedTextFieldColor")
    
    lazy var viewModel: LoginViewModel = {
        let obj = LoginViewModel()
        self.baseVwModel = obj
        return obj
    }()
    
    private let socialLoginHandler = SocialLoginHandler()
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the text field delegates to self
        txtEmail.delegate = self
        txtPassword.delegate = self
        
        // Set initial state for the UI elements
        updateUI(for: viewEmail, label: lblEmail, isFocused: false)
        updateUI(for: viewPassword, label: lblPassword, isFocused: false)
    }
    
    // MARK: - Actions
    @IBAction func btnLoginTapped(_ sender: UIButton) {
        let tabBarController = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil).instantiateViewController(withIdentifier: "TabbarController") as! TabbarController
        navigationController?.pushViewController(tabBarController, transitionType: .reveal, duration: 0.03)
    }
    
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
    
    @IBAction func btnSignUpTapped(_ sender: UIButton) {
        let signUpVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SignUpViewController") as! SignUpViewController
        self.navigationController?.pushViewController(signUpVC, transitionType: .fade)
    }
    
    @IBAction func btnGoogleLoginTapped(_ sender: UIButton) {
        // Ensure the entire sign-in process is initiated on the main thread.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Use the handler to start the Google Sign-In process.
            self.socialLoginHandler.signInWithGoogle(presentingVC: self) { result in
                // The completion handler from the SDK will often return on a background thread,
                // so we still need to dispatch any UI updates back to the main thread.
                DispatchQueue.main.async {
                    switch result {
                    case .success(_):
                        print("Google Sign In Successful, now signing into Firebase...")
                        let dashBoard = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil).instantiateViewController(withIdentifier: "TabbarController") as! TabbarController
                        self.navigationController?.pushViewController(dashBoard, transitionType: .reveal, duration: 0.03)
                        
                    case .failure(let error):
                        print("Google Sign-In Failed with error: \(error.localizedDescription)")
                        // Show an alert to the user here.
                    }
                }
            }
        }
    }
    
    @IBAction func btnFacebookLoginTapped(_ sender: UIButton) {
        // Use the handler to start the Facebook Sign-In process.
        socialLoginHandler.signInWithFacebook(presentingVC: self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    // --- SUCCESS ---
                    // The handler has successfully created the Firebase credential.
                    // Now, sign in to Firebase.
                    print("Facebook Sign In Successful, now signing into Firebase...")
                    let dashBoard = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil).instantiateViewController(withIdentifier: "TabbarController") as! TabbarController
                    self.navigationController?.pushViewController(dashBoard, transitionType: .reveal, duration: 0.03)
                    
                case .failure(let error):
                    // --- FAILURE ---
                    print("Facebook Sign-In Failed with error: \(error.localizedDescription)")
                    // You can show an alert to the user here.
                }
            }
        }
    }
    
    @IBAction func btnAppleLoginTapped(_ sender: UIButton) {
        socialLoginHandler.signInWithApple(presentingVC: self, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    // --- SUCCESS ---
                    // The handler has successfully created the Firebase credential.
                    // Now, sign in to Firebase.
                    print("Apple Sign In Successful, now signing into Firebase...")
                    let dashBoard = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil).instantiateViewController(withIdentifier: "TabbarController") as! TabbarController
                    self.navigationController?.pushViewController(dashBoard, transitionType: .reveal, duration: 0.03)
                    
                case .failure(let error):
                    // --- FAILURE ---
                    print("Apple Sign-In Failed with error: \(error.localizedDescription)")
                    // You can show an alert to the user here.
                }
            }
        })
    }
    
    // MARK: - Helper Methods
    
    /// Updates the border and label color for a text field's container.
    func updateUI(for view: UIView, label: UILabel, isFocused: Bool) {
        let color = isFocused ? focusedColor : normalColor
        
        // Animate the color changes for a smoother effect
        UIView.animate(withDuration: 0.3) {
            view.borderColor = color
            label.textColor = color
        }
    }
}

// MARK: - UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    
    /// This method is called when a user taps on a text field.
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == txtEmail {
            updateUI(for: viewEmail, label: lblEmail, isFocused: true)
        } else if textField == txtPassword {
            updateUI(for: viewPassword, label: lblPassword, isFocused: true)
        }
    }
    
    /// This method is called when a user taps away from a text field.
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == txtEmail {
            updateUI(for: viewEmail, label: lblEmail, isFocused: false)
        } else if textField == txtPassword {
            updateUI(for: viewPassword, label: lblPassword, isFocused: false)
        }
    }
}
