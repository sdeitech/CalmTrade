//
//  HomeViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 29/08/25.
//


import Foundation
import UIKit

class HomeViewModel: BaseViewModel {
    
    // MARK: - State Properties
    
    var isHealthKitConnected: Bool = false
    var isPolarConnected: Bool = false
    
    // MARK: - UI State Enum
    
    enum ButtonState {
        case onlyNoTrade
        case appleConnected
        case polarConnected
        case bothConnected
    }
    
    var onStateUpdate: ((ButtonState) -> Void)?
    
    // MARK: - Emotion Tag Data
    
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
    
    func determineButtonState() {
        if isHealthKitConnected && isPolarConnected {
            onStateUpdate?(.bothConnected)
        } else if isHealthKitConnected {
            onStateUpdate?(.appleConnected)
        } else if isPolarConnected {
            onStateUpdate?(.polarConnected)
        } else {
            onStateUpdate?(.onlyNoTrade)
        }
    }
    
    /// Toggles the selection state for an emotion at a given index and category.
    func toggleEmotionSelection(at index: Int, for category: HomeViewController.EmotionCategory) {
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
}


