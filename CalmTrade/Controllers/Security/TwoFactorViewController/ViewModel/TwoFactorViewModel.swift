//
//  TwoFactorViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 05/01/26.
//

import Foundation
import UIKit

final class TwoFactorViewModel {

    enum State {
        case idle
        case loading
        case error(String)
        case showOTP
    }

    private let api: APIService
    var onStateChange: ((State) -> Void)?

    init(api: APIService = APIService()) {
        self.api = api
    }

    func enable2FA(email: String) {
        onStateChange?(.loading)

        api.startService(
            with: .POST,
            path: "user/2fa/enable",
            parameters: nil,
            files: nil,
            modelType: TwoFAEnableResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .Success(let res):
                    guard let res else { return }
                    self?.openAuthenticator(secret: res.manualEntryKey, email: email)
                    self?.onStateChange?(.showOTP)

                case .Error(let msg):
                    self?.onStateChange?(.error(msg))
                }
            }
        }
    }

    func verifyEnable(token: String) {
        verify(path: "user/2fa/verify-setup", token: token)
    }

    func verifyDisable(token: String) {
        verify(path: "user/2fa/disable", token: token)
    }

    private func verify(path: String, token: String) {
        onStateChange?(.loading)

        api.startService(
            with: .POST,
            path: path,
            parameters: ["token": token],
            files: nil,
            modelType: GenericResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .Success:
                    self?.onStateChange?(.idle)
                case .Error(let msg):
                    self?.onStateChange?(.error(msg))
                }
            }
        }
    }

    private func openAuthenticator(secret: String, email: String) {
        let issuer = "CalmTrade"
        let urlString =
        "otpauth://totp/\(issuer):\(email)?secret=\(secret)&issuer=\(issuer)"

        guard let url = URL(string: urlString),
              UIApplication.shared.canOpenURL(url) else { return }

        UIApplication.shared.open(url)
    }
}
