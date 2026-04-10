//
//  EmotionalTagsViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 28/08/25.
//

import UIKit

class EmotionalTagsViewModel {

    // MARK: - Data
    var positiveEmotions: [EmotionTag] = []
    var negativeEmotions: [EmotionTag] = []
    var neutralEmotions: [EmotionTag] = []
    var cognitiveEmotions: [EmotionTag] = []

    // MARK: - Outputs
    var onDataLoaded: (() -> Void)?

    // MARK: - Fetch
    func fetchEmotionTags() {
        APIService().startService(
            with: .GET,
            path: "emotionalTags/tags",
            parameters: nil,
            files: nil,
            modelType: EmotionTagsResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                switch result {
                case .Success(let response):
                    guard let categories = response?.categories else { return }
                    self.map(categories)
                    self.onDataLoaded?()

                case .Error(let message):
                    print("❌ EmotionalTags fetch failed:", message)
                }
            }
        }
    }

    // MARK: - Mapping
    private func map(_ categories: [EmotionCategoryDTO]) {
        for cat in categories {

            let tags = cat.tags.map {
                EmotionTag(
                    title: $0.name,
                    valence: $0.valence,
                    arousal: $0.arousal,
                    isSelected: false
                )
            }

            switch cat.name.lowercased() {
            case "positive": positiveEmotions = tags
            case "negative": negativeEmotions = tags
            case "neutral":  neutralEmotions = tags
            case "cognitive":cognitiveEmotions = tags
            default: break
            }
        }
    }

    // MARK: - Selection
    func toggleSelection(category: Category, index: Int) {
        switch category {
        case .positive:
            positiveEmotions[index].isSelected.toggle()
        case .negative:
            negativeEmotions[index].isSelected.toggle()
        case .neutral:
            neutralEmotions[index].isSelected.toggle()
        case .cognitive:
            cognitiveEmotions[index].isSelected.toggle()
        }
    }

    enum Category {
        case positive, negative, neutral, cognitive
    }
}


struct EmotionTag {
    let title: String
    let valence: Double
    let arousal: Double
    var isSelected: Bool = false
}
