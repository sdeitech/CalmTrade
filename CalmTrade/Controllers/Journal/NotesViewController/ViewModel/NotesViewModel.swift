//
//  NotesViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 13/01/26.
//


import Foundation

final class NotesViewModel {

    // MARK: - Outputs
    var onLoading: ((Bool) -> Void)?
    var onDataReload: (() -> Void)?
    var onError: ((String) -> Void)?

    // MARK: - Data
    private(set) var notes: [Note] = []

    private let api: ApiServiceProtocol = APIService()

    // MARK: - API
    func fetchNotes(for date: Date) {
        onLoading?(true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dateString = formatter.string(from: date)

        let params: [String: Any] = [
            "date": dateString
        ]

        api.startService(
            with: .GET,
            path: "session/notes",
            parameters: params,
            files: nil,
            modelType: NotesResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoading?(false)

                switch result {
                case .Success(let response):
                    guard response?.success == true else {
                        self?.onError?("Failed to load notes")
                        return
                    }
                    self?.notes = response?.data ?? []
                    self?.onDataReload?()

                case .Error(let message):
                    self?.onError?(message)
                }
            }
        }
    }

    // MARK: - Helpers
    func numberOfRows() -> Int {
        notes.count
    }

    func note(at index: Int) -> Note {
        notes[index]
    }
}
