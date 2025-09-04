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
    
    // MARK: - Data Bindings (Outputs to ViewController)
    
    var onStateUpdate: ((ButtonState) -> Void)?
    var onEmotionDeselected: ((_ category: HomeViewController.EmotionCategory, _ index: Int) -> Void)?
    var onCalmScoreUpdate: ((_ score: Int, _ color: UIColor) -> Void)?

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

    // MARK: - Private Properties
    
    private var selectionTimers: [String: Timer] = [:]
    private var lastBiometrics: CalmScoreBiometricInputs?

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
    
    /// Initiates the live CalmScore update system.
    func startLiveUpdates() {
        // Subscribe to the DeviceManager's live updates.
        DeviceManager.shared.onLiveCalmScoreUpdate = { [weak self] session in
            let score = Int(session.calmScore.rounded())
            let color = self?.colorForScore(score) ?? .systemGreen
            self?.onCalmScoreUpdate?(score, color)
        }
        
        // Tell the DeviceManager to start the process.
        DeviceManager.shared.startLiveCalmScoreUpdates(for: .pre) { [weak self] initialBiometrics in
            // Cache the initial biometrics to use for emotion-based recalculations.
            self?.lastBiometrics = initialBiometrics
        }
    }
    
    /// Toggles an emotion's selection, allowing multiple selections, and manages an independent 10-second timer for each.
    func toggleEmotionSelection(at index: Int, for category: HomeViewController.EmotionCategory) {
        let timerKey = "\(category)-\(index)"

        // 1. Toggle the emotion's state in the data model.
        let isNowSelected = toggleEmotionState(at: index, for: category)
        
        // 2. Manage the timer based on the new state.
        if isNowSelected {
            selectionTimers[timerKey]?.invalidate() // Invalidate any old timer for this key
            let timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                self?.deselectEmotion(at: index, for: category)
                self?.onEmotionDeselected?(category, index)
                self?.selectionTimers.removeValue(forKey: timerKey)
                self?.triggerRecalculationWithCurrentEmotions() // Recalculate after timer expires
            }
            selectionTimers[timerKey] = timer
        } else {
            // If the user manually deselected it, invalidate and remove the timer.
            selectionTimers[timerKey]?.invalidate()
            selectionTimers.removeValue(forKey: timerKey)
        }
        
        // 3. Trigger a CalmScore recalculation with the new emotional context.
        triggerRecalculationWithCurrentEmotions()
    }
    
    // MARK: - Private: CalmScore Calculation Logic
    
    /// Gathers selected emotions, maps them to inputs, and tells the DeviceManager to recalculate the score.
    private func triggerRecalculationWithCurrentEmotions() {
        guard let biometrics = lastBiometrics else {
            print("Waiting for initial biometric data...")
            return
        }
        
        let selectedEmotion = findFirstSelectedEmotion()
        let emotionInputs = mapEmotionToInputs(emotionTag: selectedEmotion)
        
        DeviceManager.shared.recalculateLiveCalmScore(with: biometrics, emotionInputs: emotionInputs, for: .pre)
    }
    
    /// Finds the first selected emotion across all categories (for simplicity in the Edge score model).
    private func findFirstSelectedEmotion() -> EmotionTag? {
        if let emotion = positiveEmotions.first(where: { $0.isSelected }) { return emotion }
        if let emotion = negativeEmotions.first(where: { $0.isSelected }) { return emotion }
        if let emotion = neutralEmotions.first(where: { $0.isSelected }) { return emotion }
        if let emotion = cognitiveEmotions.first(where: { $0.isSelected }) { return emotion }
        return nil
    }
    
    /// Maps an emotion title to a simplified valence and arousal score.
    private func mapEmotionToInputs(emotionTag: EmotionTag?) -> EmotionInputs? {
        guard let emotionTag = emotionTag else { return nil }
        
        switch emotionTag.title {
        case "Calm", "Clarity", "Confidence", "Gratitude":
            return EmotionInputs(valence: 0.8, arousal: 0.2)
        case "Focused":
            return EmotionInputs(valence: 0.6, arousal: 0.4)
        case "Fear", "Frustration", "FOMO", "Revenge":
            return EmotionInputs(valence: -0.8, arousal: 0.8)
        case "Greed":
            return EmotionInputs(valence: -0.6, arousal: 0.9)
        case "Boredom", "Distraction", "Uncertainty":
            return EmotionInputs(valence: -0.2, arousal: 0.3)
        case "Curiosity":
            return EmotionInputs(valence: 0.4, arousal: 0.5)
        case "Anticipatory High":
            return EmotionInputs(valence: 0.7, arousal: 0.7)
        default:
            return EmotionInputs(valence: 0.0, arousal: 0.5)
        }
    }
    
    // MARK: - Private: Helpers
    
    private func toggleEmotionState(at index: Int, for category: HomeViewController.EmotionCategory) -> Bool {
        switch category {
        case .positive:
            positiveEmotions[index].isSelected.toggle()
            return positiveEmotions[index].isSelected
        case .negative:
            negativeEmotions[index].isSelected.toggle()
            return negativeEmotions[index].isSelected
        case .neutral:
            neutralEmotions[index].isSelected.toggle()
            return neutralEmotions[index].isSelected
        case .cognitive:
            cognitiveEmotions[index].isSelected.toggle()
            return cognitiveEmotions[index].isSelected
        }
    }
    
    private func deselectEmotion(at index: Int, for category: HomeViewController.EmotionCategory) {
        switch category {
        case .positive:
            guard index < positiveEmotions.count else { return }
            positiveEmotions[index].isSelected = false
        case .negative:
            guard index < negativeEmotions.count else { return }
            negativeEmotions[index].isSelected = false
        case .neutral:
            guard index < neutralEmotions.count else { return }
            neutralEmotions[index].isSelected = false
        case .cognitive:
            guard index < cognitiveEmotions.count else { return }
            cognitiveEmotions[index].isSelected = false
        }
    }
    
    private func colorForScore(_ score: Int) -> UIColor {
        if score > 75 { return .systemGreen }
        if score > 50 { return .systemYellow }
        return .systemRed
    }
}



