//
//  ChangePasswordViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 05/01/26.
//


import Foundation

final class ChangePasswordViewModel {

    // MARK: - Inputs
    var currentPassword: String = ""
    var newPassword: String = ""
    var confirmPassword: String = ""

    // MARK: - Validation
    func validate() -> (Bool, String?) {

        guard !currentPassword.isEmpty else {
            return (false, "Please enter current password.")
        }

        guard !newPassword.isEmpty else {
            return (false, "Please enter new password.")
        }

        guard newPassword == confirmPassword else {
            return (false, "New password and confirm password do not match.")
        }

        let pswd = newPassword

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

    // MARK: - API
    func submit(completion: @escaping (Bool, String?) -> Void) {

        let params: [String: Any] = [
            "oldPassword": currentPassword,
            "newPassword": newPassword
        ]

        APIService().startService(
            with: .POST,
            path: "user/change-password",
            parameters: params,
            files: nil,
            modelType: GenericSuccessResponse.self
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .Success(_):
                    completion(true, nil)
                case .Error(let msg):
                    completion(false, msg)
                }
            }
        }
    }
}
