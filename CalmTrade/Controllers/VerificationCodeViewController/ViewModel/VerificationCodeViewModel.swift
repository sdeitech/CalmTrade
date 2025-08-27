//
//  VerificationCodeViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 26/08/25.
//


import Foundation

class VerificationCodeViewModel: BaseViewModel {
    
    // MARK: - Properties
    
    // This would be the actual OTP received from your server.
    // For now, we'll use a placeholder.
    var correctOTP: String = "1234" // Example OTP
    
    var onValidationResult: ((Bool, String?) -> Void)?
    var onResendResult: ((String) -> Void)?

    // MARK: - Public Methods

    /// Validates the OTP entered by the user.
    /// - Parameter enteredOTP: The 4-digit string entered by the user.
    func validate(enteredOTP: String) {
        if enteredOTP.isEmpty {
            onValidationResult?(false, "Please enter the code.")
            return
        }
        
        if enteredOTP.count < 4 {
            onValidationResult?(false, "Please enter the complete 4-digit code.")
            return
        }
        
        if enteredOTP == correctOTP {
            onValidationResult?(true, nil)
        } else {
            onValidationResult?(false, "The code you entered is incorrect.")
        }
    }
    
    /// Handles the logic for resending the OTP.
    func resendCode() {
        // In a real app, you would make an API call here to resend the code.
        // For now, we'll simulate it and provide feedback to the user.
        print("Resend code logic would be triggered here.")
        onResendResult?("A new code has been sent to your email.")
    }
}
