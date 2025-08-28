//
//  EmotionalTagsViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 28/08/25.
//

import UIKit

class EmotionalTagsViewModel {
    
    // MARK: - Properties
    
    var positiveEmotions: [EmotionTag] = [
        EmotionTag(title: "Calm", isSelected: false),
        EmotionTag(title: "Clarity", isSelected: false),
        EmotionTag(title: "Focused", isSelected: false),
        EmotionTag(title: "Confidence", isSelected: false),
        EmotionTag(title: "Gratitude", isSelected: false)
    ]
    
    var negativeEmotions: [EmotionTag] = [
        EmotionTag(title: "Fear", isSelected: false),
        EmotionTag(title: "Greed", isSelected: false),
        EmotionTag(title: "Frustration", isSelected: false),
        EmotionTag(title: "FOMO", isSelected: false),
        EmotionTag(title: "Revenge", isSelected: false)
    ]
    
    var neutralEmotions: [EmotionTag] = [
        EmotionTag(title: "Boredom", isSelected: false),
        EmotionTag(title: "Distraction", isSelected: false),
        EmotionTag(title: "Revenge", isSelected: false),
        EmotionTag(title: "Uncertainty", isSelected: false),
        EmotionTag(title: "Curiosity", isSelected: false)
    ]
    
    var cognitiveEmotions: [EmotionTag] = [
        EmotionTag(title: "Anticipatory High", isSelected: false),
        EmotionTag(title: "Indecision", isSelected: false),
        EmotionTag(title: "Execution Freeze", isSelected: false),
        EmotionTag(title: "System Override", isSelected: false),
        EmotionTag(title: "Spike Stress", isSelected: false)
    ]
    
    
    
    // MARK: - Public Methods
    
    func toggleSelection(for emotion: EmotionTag, in collectionView: UICollectionView) {
        
        if let index = positiveEmotions.firstIndex(where: { $0.title == emotion.title }) {
            positiveEmotions[index].isSelected.toggle()
        }
        
        if let index = negativeEmotions.firstIndex(where: { $0.title == emotion.title }) {
            negativeEmotions[index].isSelected.toggle()
        }
        
        if let index = neutralEmotions.firstIndex(where: { $0.title == emotion.title }) {
            neutralEmotions[index].isSelected.toggle()
        }
        
        if let index = cognitiveEmotions.firstIndex(where: { $0.title == emotion.title }) {
            cognitiveEmotions[index].isSelected.toggle()
        }
    }
}

struct EmotionTag {
    let title: String
    var isSelected: Bool
}
