//
//  SignUpViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/08/25.
//

import UIKit
import KRProgressHUD
import GoogleSignIn
import FBSDKCoreKit

final class SignUpViewController: BaseViewController {
    
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
    
    private let socialLoginHandler = SocialLoginHandler() // keep for later if needed
    
    // MARK: - App Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        txtName.delegate = self
        txtEmail.delegate = self
        txtPhone.delegate = self
        txtPassword.delegate = self
        
        updateUI(for: viewName, label: lblName, isFocused: false)
        updateUI(for: viewEmail, label: lblEmail, isFocused: false)
        updateUI(for: viewPhone, label: lblPhone, isFocused: false)
        updateUI(for: viewPassword, label: lblPassword, isFocused: false)
        
        viewModel.setupTappableLabel(label: lblTerms, action: #selector(handleLabelTap(_:)))
    }
    
    // MARK: - Actions
    
    @IBAction func btnPasswordEyeTapped(_ sender: UIButton) {
        txtPassword.isSecureTextEntry.toggle()
        let icon = txtPassword.isSecureTextEntry ? "eye.slash" : "eye"
        btnPasswordEye.setImage(UIImage(systemName: icon), for: .normal)
    }
    
    @IBAction func btnCheckboxTapped(_ sender: UIButton) {
        viewModel.isCheckboxSelected.toggle()
        btnCheckbox.setImage(viewModel.isCheckboxSelected ? viewModel.selectedImage : viewModel.unselectedImage,
                             for: .normal)
    }
    
    @IBAction func btnLoginTapped(_ sender: UIButton) {
        navigationController?.popViewController(transitionType: .fade)
    }
    
    @IBAction func btnSignUpTapped(_ sender: UIButton) {
        let fullName = txtName.text
        let email    = txtEmail.text
        let phone    = txtPhone.text
        let password = txtPassword.text
        
        // 1) Validate
        let validation = viewModel.validate(fullName: fullName, email: email, phoneNumber: phone, password: password)
        guard validation.isValid else {
            showAlert(message: validation.error ?? "Please check your details.")
            return
        }
        
        // 2) Register via backend (not Firebase)
        sender.isEnabled = false
        LoaderManager.shared.show()
        viewModel.register(fullName: fullName!, email: email!, phone: phone!, password: password!) { [weak self] success, message in
            DispatchQueue.main.async {
                sender.isEnabled = true
                LoaderManager.shared.hide()
                if success {
                    // 3) Move to Email Verification (socket-based)
                    let vc = UIStoryboard(name: "Main", bundle: nil)
                        .instantiateViewController(withIdentifier: "EmailVerificationViewController") as! EmailVerificationViewController
                    vc.passedEmail = email
                    self?.navigationController?.pushViewController(vc, transitionType: .fade)
                } else {
                    self?.showAlert(message: message ?? "Please try again.")
                }
            }
        }
    }
    
    @IBAction func btnGoogleLoginTapped(_ sender: UIButton) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.socialLoginHandler.signInWithGoogle(presentingVC: self) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(_):
                        guard let idToken = self.socialLoginHandler.lastGoogleIDToken else {
                            self.showAlert(message: "Couldn’t retrieve Google ID token.")
                            return
                        }
                        LoaderManager.shared.show()
                        self.viewModel.googleAuth(idToken: idToken) { [weak self] ok, msg, isFirst  in
                            guard let self = self else { return }
                            LoaderManager.shared.hide()
                            if ok {
                                UserDefaults.standard.set(LoginHandler.google.rawValue, forKey: kLoginHandler)
                                if isFirst {
                                    let connectVC = UIStoryboard(name: Constants.Storyboard.Devices, bundle: nil)
                                        .instantiateViewController(withIdentifier: "ConnectViewController") as! ConnectViewController
                                    navigationController?.pushViewController(connectVC, transitionType: .reveal, duration: 0.03)
                                } else {
                                    self.openDashboard()
                                }
                            }
                            else { self.showAlert(message: msg ?? "Google auth failed. Please try again.") }
                        }
                    case .failure(let error):
                        print("Google Sign-In Failed:", error.localizedDescription)
                        self.showAlert(message: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    @IBAction func btnFacebookLoginTapped(_ sender: UIButton) {
        socialLoginHandler.signInWithFacebook(presentingVC: self) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let cred):
                    let sdkAccess = AccessToken.current
                    print("FB SDK AccessToken.current?:", sdkAccess != nil)
                    print("FB SDK access token string:", sdkAccess?.tokenString ?? "nil")
                    print("FB SDK appID:", sdkAccess?.appID ?? "nil")
                    print("FB SDK userID:", sdkAccess?.userID ?? "nil")
                    
                    // If Limited Login was (accidentally) used, this will be non-nil:
                    print("FB AuthenticationToken.current?:", AuthenticationToken.current != nil)
                    print("FB AuthenticationToken (JWT):", AuthenticationToken.current?.tokenString ?? "nil")
                    
                    
                    guard let token = cred.accessToken, let name = cred.fullName, let email = cred.email, let userId = cred.userID, let imageUrl = cred.avatarURL, !token.isEmpty else {
                        self.showAlert(message: "Facebook login succeeded, but access token is missing.")
                        return
                    }
                    LoaderManager.shared.show()
                    self.viewModel.facebookAuth(accessToken: token,name: name,email: email,userId: userId, imageUrl: imageUrl) { [weak self] ok, msg, isFirst in
                        guard let self = self else { return }
                        LoaderManager.shared.hide()
                        if ok {
                            UserDefaults.standard.set(LoginHandler.facebook.rawValue, forKey: kLoginHandler)
                            if isFirst {
                                let connectVC = UIStoryboard(name: Constants.Storyboard.Devices, bundle: nil)
                                    .instantiateViewController(withIdentifier: "ConnectViewController") as! ConnectViewController
                                navigationController?.pushViewController(connectVC, transitionType: .reveal, duration: 0.03)
                            } else {
                                self.openDashboard()
                            }
                        }
                        else { self.showAlert(message: msg ?? "Facebook auth failed. Please try again.") }
                    }
                    
                case .failure(let error):
                    print("Facebook Sign-In Failed:", error.localizedDescription)
                    self.showAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    @IBAction func btnAppleLoginTapped(_ sender: UIButton) {
        socialLoginHandler.signInWithApple(presentingVC: self) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let cred):
                    // We need identityToken + authorizationCode for your backend.
                    guard let idToken = cred.idToken, !idToken.isEmpty else {
                        self.showAlert(message: "Missing Apple identity token.")
                        return
                    }
                    guard let authCode = cred.authorizationCode, !authCode.isEmpty else {
                        self.showAlert(message: "Missing Apple authorization code.")
                        return
                    }
                    guard let givenName = cred.givenName, let familyName = cred.familyName else {
                        self.showAlert(message: "Missing Apple given name or family name.")
                        return
                    }
                    LoaderManager.shared.show()
                    self.viewModel.appleAuth(identityToken: idToken, authorizationCode: authCode, givenName: givenName, familyName: familyName) { [weak self] ok, msg, isFirst in
                        LoaderManager.shared.hide()
                        guard let self = self else { return }
                        if ok {
                            UserDefaults.standard.set(LoginHandler.apple.rawValue, forKey: kLoginHandler)
                            if isFirst {
                                let connectVC = UIStoryboard(name: Constants.Storyboard.Devices, bundle: nil)
                                    .instantiateViewController(withIdentifier: "ConnectViewController") as! ConnectViewController
                                navigationController?.pushViewController(connectVC, transitionType: .reveal, duration: 0.03)
                            } else {
                                self.openDashboard()
                            }
                        }
                        else { self.showAlert(message: msg ?? "Apple auth failed. Please try again.") }
                    }
                case .failure(let error):
                    print("Apple Sign-In Failed:", error.localizedDescription)
                    self.showAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToVerificationScreen() {
        let verificationVC = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "EmailVerificationViewController") as! EmailVerificationViewController
        navigationController?.pushViewController(verificationVC, transitionType: .fade)
    }
    
    private func openDashboard() {
        let dashBoard = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil)
            .instantiateViewController(withIdentifier: "TabbarController") as! TabbarController
        self.navigationController?.pushViewController(dashBoard, transitionType: .reveal, duration: 0.03)
    }
    
    func updateUI(for view: UIView, label: UILabel, isFocused: Bool) {
        let color = isFocused ? viewModel.focusedColor : viewModel.normalColor
        UIView.animate(withDuration: 0.3) {
            view.borderColor = color
            label.textColor  = color
        }
    }
    
    @objc private func handleLabelTap(_ gesture: UITapGestureRecognizer) {
        guard let label = gesture.view as? UILabel,
              let attributedText = label.attributedText else { return }
        let fullText = attributedText.string
        let tapLocation = gesture.location(in: label)
        let characterIndex = viewModel.characterIndex(for: tapLocation, in: label)
        
        if let termsRange = fullText.range(of: "Terms & Conditions"),
           NSRange(termsRange, in: fullText).contains(characterIndex ?? 0) {
            viewModel.openURL(urlString: "https://www.example.com/terms", in: self)
        }
        if let policyRange = fullText.range(of: "Data Privacy Policy"),
           NSRange(policyRange, in: fullText).contains(characterIndex ?? 0) {
            viewModel.openURL(urlString: "https://www.example.com/privacy", in: self)
        }
    }
}

// MARK: - UITextFieldDelegate
extension SignUpViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == txtName { updateUI(for: viewName, label: lblName, isFocused: true) }
        else if textField == txtEmail { updateUI(for: viewEmail, label: lblEmail, isFocused: true) }
        else if textField == txtPhone { updateUI(for: viewPhone, label: lblPhone, isFocused: true) }
        else if textField == txtPassword { updateUI(for: viewPassword, label: lblPassword, isFocused: true) }
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == txtName { updateUI(for: viewName, label: lblName, isFocused: false) }
        else if textField == txtEmail { updateUI(for: viewEmail, label: lblEmail, isFocused: false) }
        else if textField == txtPhone { updateUI(for: viewPhone, label: lblPhone, isFocused: false) }
        else if textField == txtPassword { updateUI(for: viewPassword, label: lblPassword, isFocused: false) }
    }
}
