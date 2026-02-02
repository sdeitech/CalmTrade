//
//  DataManagementViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 29/01/26.
//


import Foundation

final class DataManagementViewModel {

    // MARK: - Outputs
    var onLoading: ((Bool) -> Void)?
    var onSuccess: (() -> Void)?
    var onError: ((String) -> Void)?

    private let api: ApiServiceProtocol = APIService()

    func deleteAllData() {
        onLoading?(true)

        api.startService(
            with: .DELETE,
            path: "userData/delete-data",
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
