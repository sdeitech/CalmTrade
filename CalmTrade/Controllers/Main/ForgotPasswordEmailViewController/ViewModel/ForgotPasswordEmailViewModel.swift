//
//  ForgotPasswordEmailViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 07/10/25.
//


//
//  ForgotPasswordEmailViewModel.swift
//  CalmTrade
//

import Foundation

final class ForgotPasswordEmailViewModel: BaseViewModel {

    // Input
    var email: String = ""

    // Dependencies
    private let repo: UserRepositoryProtocol

    // Output
    var onLoading: ((Bool) -> Void)?
    var onError: ((String) -> Void)?
    var onSuccess: ((String) -> Void)?   // message

    init(repo: UserRepositoryProtocol = UserRepository()) {
        self.repo = repo
        super.init()
    }

    // Validation
    func validate() -> String? {
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Please enter your registered email."
        }
        if !email.isValidEmail() {
            return "Please enter a valid email address."
        }
        return nil
    }

    func submit() {
        if let msg = validate() {
            onError?(msg)
            return
        }
        onLoading?(true)
        repo.forgotPassword(email: email) { [weak self] result in
            guard let self = self else { return }
            self.onLoading?(false)
            switch result {
            case .Success(let baseMsg):
                let msg = baseMsg?.message ?? "We’ve sent you an OTP on your email."
                self.onSuccess?(msg)
            case .Error(let error):
                self.onError?(error.description)
            }
        }
    }
}
