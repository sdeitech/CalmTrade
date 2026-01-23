//
//  EmotionNoteViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 21/01/26.
//


import Foundation

final class EmotionNoteViewModel: ObservableObject {

    let emotionId: String

    @Published var content: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var didSave = false

    init(emotionId: String) {
        self.emotionId = emotionId
    }

    func save() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Note cannot be empty."
            return
        }

        isLoading = true
        errorMessage = nil

        EmotionNoteService.addNote(
            emotionId: emotionId,
            content: trimmed
        ) { [weak self] success, message in
            DispatchQueue.main.async {
                self?.isLoading = false
                if success {
                    self?.didSave = true
                } else {
                    self?.errorMessage = message ?? "Failed to save note."
                }
            }
        }
    }
}

enum EmotionNoteService {

    static func addNote(
        emotionId: String,
        content: String,
        completion: @escaping (Bool, String?) -> Void
    ) {

        let api: ApiServiceProtocol = APIService()
        let path = "session/emotion/\(emotionId)/notes"

        let params: [String: Any] = [
            "content": content,
            "noteType": "Emotion"
        ]

        api.startService(
            with: .POST,
            path: path,
            parameters: params,
            files: nil,
            modelType: EmptyResponse.self
        ) { result in
            switch result {
            case .Success:
                completion(true, nil)
            case .Error(let msg):
                completion(false, msg)
            }
        }
    }
}
