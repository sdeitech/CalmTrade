//
//  EmailVerificationViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 26/08/25.
//

import UIKit

final class EmailVerificationViewController: BaseViewController {

    // MARK: - Outlets
    @IBOutlet weak var lblEmail: UILabel!
    
    // MARK: - Properties
    /// Set by previous screen (SignUp / Login) before push
    var passedEmail: String?
    
    /// If the app was opened by a deep link directly into this VC, you may set this before presenting/pushing.
    /// DeepLinkRouter can also call `viewModel.verifyViaDeepLink(token:email:)` directly.
    var deepLinkToken: String?
    
    lazy var viewModel: EmailVerificationViewModel = {
        let obj = EmailVerificationViewModel()
        self.baseVwModel = obj
        return obj
    }()

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
        if let email = passedEmail, !email.isEmpty {
            lblEmail.text = email
        }
        
        // If a token was injected before showing this screen (optional helper)
        if let token = deepLinkToken, !token.isEmpty {
            viewModel.verifyViaDeepLink(token: token, email: passedEmail)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.startListeningForVerification(email: passedEmail)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopListening()
    }
    
    // MARK: - Bindings
    private func setupBindings() {
        viewModel.onVerificationStatusChanged = { [weak self] verified in
            guard let self = self else { return }
            if verified { self.navigateToEmailVerifiedScreen() }
        }
        viewModel.onResendEmailResult = { [weak self] errorMessage in
            guard let self = self else { return }
            if let msg = errorMessage {
                self.showAlert(message: msg)
            } else {
                self.showAlert(message: "A new verification email has been sent.")
            }
        }
    }
    
    // MARK: - Actions
    @IBAction func btnEnterManuallyTapped(_ sender: UIButton) {
        let vc = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "VerificationCodeViewController") as! VerificationCodeViewController
        vc.email = self.passedEmail
        navigationController?.pushViewController(vc, transitionType: .fade)
    }
    
    @IBAction func btnBackToSignupTapped(_ sender: UIButton) {
        navigationController?.popViewController()
    }
    
    // MARK: - Navigation
    private func navigateToEmailVerifiedScreen() {
        let verifiedVC = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "EmailVerifiedViewController") as! EmailVerifiedViewController
        navigationController?.pushViewController(verifiedVC, transitionType: .fade)
    }
}
