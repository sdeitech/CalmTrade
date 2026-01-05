//
//  EmotionStore.swift
//  CalmTrade
//
//  Created by Anas Parekh on 11/09/25.
//


// EmotionStore.swift
import Foundation

/// Optional emotion inputs for the Edge component.
public struct EmotionInputs: Codable {
    public let valence: Double // -1 (negative) to +1 (positive)
    public let arousal: Double // 0 (calm) to 1 (excited/activated)
    public init(valence: Double, arousal: Double) {
        self.valence = valence
        self.arousal = arousal
    }
}

/// Global emotion state for the session. Home sets it; all screens read it.
final class EmotionStore {
    static let shared = EmotionStore()

    /// Current emotion inputs (nil = neutral/no override)
    private(set) var current: EmotionInputs? {
        didSet { onChange?(current) }
    }

    /// Observer (single; if you need multicast later, add a registry like in PolarManager)
    var onChange: ((EmotionInputs?) -> Void)?

    private init() {}

    /// Map a tag title to EmotionInputs used by the score model.
    func set(from tag: EmotionTag?) {
        guard let tag = tag else {
            current = nil
            return
        }
        current = EmotionStore.map(tag: tag.title)
    }

    static func map(tag: String) -> EmotionInputs {
        switch tag {
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
}
