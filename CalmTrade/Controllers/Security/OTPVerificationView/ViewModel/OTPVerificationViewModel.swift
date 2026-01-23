//
//  OTPVerificationViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 05/01/26.
//


import Foundation

final class OTPVerificationViewModel: ObservableObject {

    let isDisabling: Bool
    private let parentVM: TwoFactorViewModel

    var onSuccess: (() -> Void)?
    var onFailure: (() -> Void)?

    init(isDisabling: Bool, parentVM: TwoFactorViewModel) {
        self.isDisabling = isDisabling
        self.parentVM = parentVM
    }

    func submit(code: String, completion: @escaping (Bool, String?) -> Void) {
        let handler: (TwoFactorViewModel.State) -> Void = { state in
            switch state {
            case .idle:
                completion(true, nil)

            case .error(let msg):
                completion(false, msg)

            default:
                break
            }
        }

        parentVM.onStateChange = handler

        if isDisabling {
            parentVM.verifyDisable(token: code)
        } else {
            parentVM.verifyEnable(token: code)
        }
    }
}
