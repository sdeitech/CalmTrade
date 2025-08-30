//
//  EmailVerificationViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 26/08/25.
//

import UIKit
import FirebaseAuth

class EmailVerificationViewController: BaseViewController {

    // MARK: - Outlets
    
    @IBOutlet weak var lblEmail: UILabel!
    
    // MARK: - Properties
    
    lazy var viewModel: EmailVerificationViewModel = {
        let obj = EmailVerificationViewModel()
        self.baseVwModel = obj
        return obj
    }()

    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewModelBindings()
        
        // Display the user's email so they know where the link was sent.
        if let email = Auth.auth().currentUser?.email {
            lblEmail.text = email
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Start checking for verification when the screen appears.
        viewModel.startCheckingVerificationStatus()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop the timer when the screen is no longer visible to save resources.
        viewModel.stopCheckingVerificationStatus()
    }
    
    // MARK: - Setup
    
    private func setupViewModelBindings() {
        // This is where the ViewController listens for changes from the ViewModel.
        viewModel.onVerificationStatusChanged = { [weak self] isVerified in
            if isVerified {
                // --- SUCCESS ---
                // Navigate to the main part of the app.
                self?.navigateToEmailVerifiedScreen()
            }
        }
        
        viewModel.onResendEmailResult = { [weak self] error in
            if let error = error {
                self?.showAlert(title: "Error", message: error.localizedDescription)
            } else {
                self?.showAlert(title: "Success", message: "A new verification email has been sent.")
            }
        }
    }
    
    // MARK: - Actions
    
//    @IBAction func btnResendEmailTapped(_ sender: UIButton) {
//        viewModel.resendVerificationEmail()
//    }
//    
//    @IBAction func btnLogOutTapped(_ sender: UIButton) {
//        viewModel.signOut()
//        // Navigate back to the login or sign-up screen.
//        self.navigationController?.popToRootViewController(animated: true)
//    }
    
    @IBAction func btnEnterManuallyTapped(_ sender: UIButton) {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "VerificationCodeViewController") as! VerificationCodeViewController
        navigationController?.pushViewController(vc, transitionType: .fade)
    }
    
    @IBAction func btnBackToSignupTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Navigation
    
    private func navigateToEmailVerifiedScreen() {
        let verifiedVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "EmailVerifiedViewController") as! EmailVerifiedViewController
        self.navigationController?.pushViewController(verifiedVC, transitionType: .fade)
    }
    
    /// Helper function to show a simple alert.
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
