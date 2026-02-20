//
//  VerificationCodeViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 26/08/25.
//

import Foundation

final class VerificationCodeViewModel: BaseViewModel {

    // MARK: - Events
    var onValidationResult: ((Bool, String?) -> Void)?
    var onResendResult: ((String) -> Void)?

    // MARK: - Models
    private struct VerifyOtpResponse: Decodable {
        let success: Bool
        let message: String?
        let accessToken: String?
        let refreshToken: String?
    }

    private struct ResendResponse: Decodable {
        let success: Bool
        let message: String?
    }

    // MARK: - Public API
    func verify(email: String?, enteredOTP: String) {
        // Validate client-side quickly
        let trimmed = enteredOTP.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            onValidationResult?(false, "Please enter the code.")
            return
        }
        guard trimmed.count >= 4 else {
            onValidationResult?(false, "Please enter the complete code.")
            return
        }
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            onValidationResult?(false, "Missing email address.")
            return
        }

        isLoading = true
        let params: [String: Any] = [
            "email": email,
            "otp": trimmed
        ]

        APIService().startService(with: .POST,
                                  path: Endpoints.Auth.verifyEmailOtp.rawValue, // <- set your actual path
                                  parameters: params,
                                  files: [],
                                  modelType: VerifyOtpResponse.self) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .Success(let resp):
                    if resp?.success == true {
                        if let token = resp?.accessToken,let refreshToken = resp?.refreshToken {
                            self.updateUserToken(token, refreshToken: refreshToken)
                        }
                        self.onValidationResult?(true, nil)
                    } else {
                        self.onValidationResult?(false, resp?.message ?? "Verification failed. Please try again.")
                    }
                case .Error(let message):
                    self.onValidationResult?(false, message ?? "Verification failed. Please try again.")
                }
            }
        }
    }

    func resendCode(to email: String?) {
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            onValidationResult?(false, "Missing email address.")
            return
        }

        isLoading = true
        let params: [String: Any] = ["email": email]

        APIService().startService(with: .POST,
                                  path: Endpoints.Auth.resendVerification.rawValue, // <- set your actual path if supported
                                  parameters: params,
                                  files: [],
                                  modelType: ResendResponse.self) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .Success(let resp):
                    if resp?.success == true {
                        self.onResendResult?(resp?.message ?? "A new code has been sent to your email.")
                    } else {
                        self.onValidationResult?(false, resp?.message ?? "Failed to resend code.")
                    }
                case .Error(let message):
                    self.onValidationResult?(false, message ?? "Failed to resend code.")
                }
            }
        }
    }
}
