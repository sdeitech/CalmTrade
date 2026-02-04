//
//  DeleteAccountViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/02/26.
//


import Foundation

final class DeleteAccountViewModel {

    // MARK: - Outputs
    var onLoading: ((Bool) -> Void)?
    var onSuccess: (() -> Void)?
    var onError: ((String) -> Void)?

    private let api: ApiServiceProtocol = APIService()

    func deleteAccount(userId: String) {
        onLoading?(true)

        let path = "user/\(userId)/deleteUser"

        api.startService(
            with: .DELETE,
            path: path,
            parameters: nil,
            files: nil,
            modelType: EmptyResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoading?(false)

                switch result {
                case .Success:
                    self?.onSuccess?()
                case .Error(let msg):
                    self?.onError?(msg)
                }
            }
        }
    }
}
