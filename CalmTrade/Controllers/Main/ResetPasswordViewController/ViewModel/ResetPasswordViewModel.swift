//
//  ResetPasswordViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 07/10/25.
//

import Foundation

final class ResetPasswordViewModel: BaseViewModel {
    var onResult: ((Bool, String?) -> Void)?

    private let repo: UserRepositoryProtocol
    init(repo: UserRepositoryProtocol = UserRepository()) {
        self.repo = repo
        super.init()
    }

    func reset(email: String, otp: String, newPassword: String) {
        isLoading = true
        repo.resetPassword(email: email, otp: otp, newPassword: newPassword) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .Success(let resp):
                    let ok = resp?.success == true
                    self.onResult?(ok, resp?.message ?? (ok ? "Password reset successful." : "Password reset failed."))
                case .Error(let message):
                    self.onResult?(false, message ?? "Password reset failed.")
                }
            }
        }
    }
}
