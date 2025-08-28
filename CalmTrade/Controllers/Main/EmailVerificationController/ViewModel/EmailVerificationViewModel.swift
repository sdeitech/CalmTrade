//
//  EmailVerificationViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 26/08/25.
//


import Foundation
import FirebaseAuth

class EmailVerificationViewModel: BaseViewModel {
    
    // MARK: - Properties
    
    private var timer: Timer?
    
    /// A closure that is called when the user's email verification status changes.
    var onVerificationStatusChanged: ((Bool) -> Void)?
    
    /// A closure that is called when the resend email action completes.
    var onResendEmailResult: ((Error?) -> Void)?

    // MARK: - Public Methods

    /// Starts a timer that periodically checks if the user's email has been verified.
    func startCheckingVerificationStatus() {
        // Invalidate any existing timer first.
        stopCheckingVerificationStatus()
        
        // Create a new timer that fires every 3 seconds.
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkEmailVerification()
        }
    }
    
    /// Stops the verification check timer.
    func stopCheckingVerificationStatus() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Resends the verification email to the current user.
    func resendVerificationEmail() {
        Auth.auth().currentUser?.sendEmailVerification(completion: { [weak self] error in
            self?.onResendEmailResult?(error)
        })
    }
    
    /// Signs the current user out of Firebase.
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }

    // MARK: - Private Methods

    private func checkEmailVerification() {
        guard let user = Auth.auth().currentUser else {
            // If there's no user, stop the timer.
            stopCheckingVerificationStatus()
            return
        }
        
        // 1. Reload the user's data from Firebase to get the latest status.
        user.reload { [weak self] error in
            if let error = error {
                print("Error reloading user: \(error.localizedDescription)")
                return
            }
            
            // 2. Check the isEmailVerified property.
            if user.isEmailVerified {
                print("Email has been verified!")
                // Stop the timer and notify the ViewController.
                self?.stopCheckingVerificationStatus()
                self?.onVerificationStatusChanged?(true)
            } else {
                print("Email not yet verified. Checking again in 3 seconds...")
                self?.onVerificationStatusChanged?(false)
            }
        }
    }
}
