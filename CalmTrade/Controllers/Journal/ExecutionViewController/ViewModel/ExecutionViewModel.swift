//
//  ExecutionViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 12/01/26.
//

import Foundation

final class ExecutionViewModel {

    var onLoading: ((Bool) -> Void)?
    var onError: ((String) -> Void)?
    var onData: (([ExecutionItem]) -> Void)?

    private let api = APIService()
    private var currentDate: String = ""

    func load(date: String) {
        currentDate = date
        fetchExecutions()
    }

    func refresh() {
        fetchExecutions()
    }

    private func fetchExecutions() {
        onLoading?(true)

        let params: [String: Any] = [
            "date": currentDate
        ]

        api.startService(
            with: .GET,
            path: "session/executions",
            parameters: params,
            files: nil,
            modelType: ExecutionListResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoading?(false)
                switch result {
                case .Success(let res):
                    self?.onData?(res?.data ?? [])
                case .Error(let err):
                    self?.onError?(err)
                }
            }
        }
    }
}
