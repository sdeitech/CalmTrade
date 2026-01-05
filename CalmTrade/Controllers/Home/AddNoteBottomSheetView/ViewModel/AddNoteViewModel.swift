//
//  AddNoteViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 26/12/25.
//


import Foundation

final class AddNoteViewModel: ObservableObject {

    enum TitleOption: String, CaseIterable {
        case pre = "Pre Session Plans"
        case mid = "Mid Session Notes"
        case post = "Post Session Review"
        case custom = "Custom"
    }

    // MARK: - Inputs
    @Published var selectedOption: TitleOption = .pre
    @Published var titleText: String = ""          // used only for custom
    @Published var descriptionText: String = ""

    // MARK: - Outputs
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var didSave: Bool = false

    // MARK: - Dependencies
    private let api: ApiServiceProtocol
    private let sessionId: String

    init(sessionId: String, api: ApiServiceProtocol = APIService()) {
        self.sessionId = sessionId
        self.api = api
    }

    // MARK: - Helpers
    var finalTitle: String {
        selectedOption == .custom ? titleText : selectedOption.rawValue
    }

    // MARK: - Action
    func save() {
        guard !finalTitle.trimmingCharacters(in: .whitespaces).isEmpty,
              !descriptionText.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please fill all fields"
            return
        }

        isLoading = true
        errorMessage = nil

        let params: [String: Any] = [
//            "sessionId": sessionId,
            "noteType": finalTitle,
            "content": descriptionText
        ]

        api.startService(
            with: .POST,
            path: "session/notes",
            parameters: params,
            files: nil,
            modelType: AddNoteResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .Success(let response):
                    if response?.success == false {
                        self?.errorMessage = response?.message ?? "Something went wrong"
                    } else {
                        self?.didSave = true
                    }
                case .Error(let message):
                    self?.errorMessage = message
                }
            }
        }
    }
}

