//
//  ChangeEmailViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/01/26.
//


import Foundation

final class ChangeEmailViewModel {

    // MARK: - Outputs
    var onLoading: ((Bool) -> Void)?
    var onError: ((String) -> Void)?
    var onOTPSent: ((_ oldEmail: String, _ newEmail: String) -> Void)?

    // MARK: - Validation

    func validate(oldEmail: String, newEmail: String, password: String) -> Bool {

        guard oldEmail.isValidEmail() else {
            onError?("Enter a valid current email.")
            return false
        }

        guard newEmail.isValidEmail() else {
            onError?("Enter a valid new email.")
            return false
        }

        guard oldEmail.lowercased() != newEmail.lowercased() else {
            onError?("New email must be different from current email.")
            return false
        }

        let result = password.validatePassword()
        guard result.isValid else {
            onError?(result.message ?? "Invalid password.")
            return false
        }

        return true
    }

    // MARK: - API

    func requestEmailChange(oldEmail: String, newEmail: String, password: String) {

        let params: [String: Any] = [
            "oldEmail": oldEmail,
            "newEmail": newEmail,
            "password": password
        ]

        onLoading?(true)

        APIService().startService(
            with: .POST,
            path: "user/change-email-request",
            parameters: params,
            files: nil,
            modelType: GenericResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoading?(false)

                switch result {
                case .Success(let response):
                    guard response?.success == true else {
                        self?.onError?(response?.message ?? "Failed to send OTP.")
                        return
                    }
                    self?.onOTPSent?(oldEmail, newEmail)

                case .Error(let message):
                    self?.onError?(message)
                }
            }
        }
    }
}

extension String {

    func validatePassword() -> (isValid: Bool, message: String?) {
        let pswd = self

        guard pswd.count >= 8 else {
            return (false, "Password must be at least 8 characters long.")
        }

        guard pswd.containsUppercaseLetter() else {
            return (false, "Password must contain at least one uppercase letter.")
        }

        guard pswd.containsSpecialCharacter() else {
            return (false, "Password must contain at least one special character.")
        }

        return (true, nil)
    }
}
