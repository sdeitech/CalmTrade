//
//  LoginViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/08/25.
//

import UIKit
import GoogleSignIn
import FBSDKCoreKit
import KRProgressHUD

class LoginViewController: BaseViewController {
    
    // MARK: - Outlets
    
    @IBOutlet weak var lblEmail: UILabel!
    @IBOutlet weak var viewEmail: UIView!
    @IBOutlet weak var txtEmail: UITextField!
    
    @IBOutlet weak var lblPassword: UILabel!
    @IBOutlet weak var viewPassword: UIView!
    @IBOutlet weak var txtPassword: UITextField!
    @IBOutlet weak var btnPasswordEye: UIButton!
    
    // MARK: - Properties
    
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
        txtEmail.delegate = self
        txtPassword.delegate = self
        updateUI(for: viewEmail, label: lblEmail, isFocused: false)
        updateUI(for: viewPassword, label: lblPassword, isFocused: false)
    }
    
    // MARK: - Actions
    @IBAction func btnLoginTapped(_ sender: UIButton) {
        let vm = LoginViewModel()
        vm.email = txtEmail.text ?? ""
        vm.password = txtPassword.text ?? ""
        sender.isEnabled = false
        KRProgressHUD.show()
        
        vm.submit { [weak self] success, message, needsVerification in
            guard let self = self else { return }
            sender.isEnabled = true
            KRProgressHUD.dismiss()
            
            if success {
                // Dashboard
                let tabBarController = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil)
                    .instantiateViewController(withIdentifier: "TabbarController") as! TabbarController
                self.navigationController?.pushViewController(tabBarController, transitionType: .reveal, duration: 0.03)
            } else if needsVerification {
                // Email verification
                let vc = UIStoryboard(name: "Main", bundle: nil)
                    .instantiateViewController(withIdentifier: "EmailVerificationViewController") as! EmailVerificationViewController
                vc.passedEmail = vm.email
                self.navigationController?.pushViewController(vc, transitionType: .fade)
            } else {
                self.showAlert(message: message ?? "Please try again.")
            }
        }
    }

    @IBAction func btnPasswordEyeTapped(_ sender: UIButton) {
        txtPassword.isSecureTextEntry.toggle()
        btnPasswordEye.setImage(UIImage(systemName: txtPassword.isSecureTextEntry ? "eye.slash" : "eye"), for: .normal)
    }
    
    @IBAction func btnSignUpTapped(_ sender: UIButton) {
        let signUpVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SignUpViewController") as! SignUpViewController
        self.navigationController?.pushViewController(signUpVC, transitionType: .fade)
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
                        KRProgressHUD.show()
                        self.viewModel.googleAuth(idToken: idToken) { [weak self] ok, msg, isFirst  in
                            print("🟢 VC completion thread:", Thread.isMainThread)
                            guard let self = self else { return }
                            KRProgressHUD.dismiss()
                            if ok {
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
                    KRProgressHUD.show()
                    self.viewModel.facebookAuth(accessToken: token,name: name,email: email,userId: userId, imageUrl: imageUrl) { [weak self] ok, msg, isFirst in
                        guard let self = self else { return }
                        KRProgressHUD.dismiss()
                        if ok {
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
                    KRProgressHUD.show()
                    self.viewModel.appleAuth(identityToken: idToken, authorizationCode: authCode, givenName: givenName, familyName: familyName) { [weak self] ok, msg, isFirst in
                        KRProgressHUD.dismiss()
                        guard let self = self else { return }
                        if ok {
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
    
    @IBAction func btnForgotPasswordTapped(_ sender: Any) {
        let vc = UIStoryboard(name: Constants.Storyboard.Main, bundle: nil)
            .instantiateViewController(withIdentifier: "ForgotPasswordEmailViewController") as! ForgotPasswordEmailViewController
        self.navigationController?.pushViewController(vc)
    }
    
    // MARK: - Helper Methods
    
    private func openDashboard() {
        let dashBoard = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil)
            .instantiateViewController(withIdentifier: "TabbarController") as! TabbarController
        self.navigationController?.pushViewController(dashBoard, transitionType: .reveal, duration: 0.03)
    }
    
    func updateUI(for view: UIView, label: UILabel, isFocused: Bool) {
        let color = isFocused ? focusedColor : normalColor
        UIView.animate(withDuration: 0.3) {
            view.borderColor = color
            label.textColor = color
        }
    }
}

// MARK: - UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == txtEmail {
            updateUI(for: viewEmail, label: lblEmail, isFocused: true)
        } else if textField == txtPassword {
            updateUI(for: viewPassword, label: lblPassword, isFocused: true)
        }
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == txtEmail {
            updateUI(for: viewEmail, label: lblEmail, isFocused: false)
        } else if textField == txtPassword {
            updateUI(for: viewPassword, label: lblPassword, isFocused: false)
        }
    }
}
