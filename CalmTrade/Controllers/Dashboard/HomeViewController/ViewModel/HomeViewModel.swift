import Foundation
import UIKit

final class HomeViewModel: BaseViewModel {
    
    // MARK: - Connection state (for the button cluster)
    var isHealthKitConnected: Bool = false
    var isPolarConnected: Bool = false
    var isCalm360Connected: Bool = false
    var isHRStreaming: Bool = false
    
    enum ButtonState {
        case onlyNoTrade
        case appleConnected
        case polarConnected
        case bothConnected
    }
    
    // MARK: - Outputs to ViewController
    var onStateUpdate: ((ButtonState) -> Void)?
    var onEmotionDeselected: ((_ category: HomeViewController.EmotionCategory, _ index: Int) -> Void)?
    var onPropsUpdate: ((CalmScoreTileProps) -> Void)?
    
    private var userObserver: NSObjectProtocol?
    
//    var onHRVisibility: ((Bool) -> Void)?
//    var onHRValue: ((_ hrText: String, _ timestampText: String) -> Void)?
    
    // MARK: - Hub subscription
    private var hubToken: UUID?
    private var lastBiometrics: CalmScoreBiometricInputs?
    private var currentProps: CalmScoreTileProps?
    
    private var polarObserverId: UUID?
    
    // MARK: - Emotion chips
    // MARK: - Backend-driven emotions
    var positiveEmotions: [EmotionTag] = []
    var negativeEmotions: [EmotionTag] = []
    var neutralEmotions: [EmotionTag] = []
    var cognitiveEmotions: [EmotionTag] = []

    var onEmotionDataLoaded: (() -> Void)?

    
    // MARK: - Internals
    private var selectionTimers: [String: Timer] = [:]
    
    // Sleep + work queue
    private let workQ = DispatchQueue(label: "ct.home.vm", qos: .userInitiated)
    
    // MARK: - UI wiring
    
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
    
    /// Subscribe to the global hub; override sleep trend so Home’s gauge matches SleepInsight/Biometrics.
    func startLiveUpdates() {
//        abort()
        userObserver = NotificationCenter.default.addObserver(
            forName: .userAccountDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleUserUpdate()
        }
        
        EmotionStore.shared.set(from: findFirstSelectedEmotion())
        EmotionStore.shared.onChange = { inputs in
            // if you re-enable emotion override:
            // CalmScoreHub.shared.setEmotionOverride(inputs)
            // NotificationCenter.default.post(name: .ctEmotionUpdated, object: inputs)
        }
        
        hubToken = CalmScoreHub.shared.addListener { [weak self] session, bundle, props in
            guard let self else { return }
            self.lastBiometrics = bundle
            
            // Start from incoming props
            var p = props
            
            // Pill: show "Connect" instead of "Apple HK"
            if p.deviceSource == .appleHK {
                p.deviceSource = .connect
                p.isStreaming = false
            }
            
            self.isCalm360Connected = (p.deviceSource == .calm360)
            if !self.isCalm360Connected { p.batteryPercent = nil }
            
//            // HR visibility: show if we’re streaming on a Polar device
//            let shouldShowHR = p.isStreaming && (p.deviceSource == .h10 || p.deviceSource == .calm360)
//            self.onHRVisibility?(shouldShowHR)
//            
//            if shouldShowHR {
//                let hrBpm = Int(round(p.trend.hrBpm))
//                let ts = self.formatTimestamp(p.lastUpdate)
//                self.onHRValue?("\(hrBpm) bpm", ts)
//            }
            
            // Override sleep trend so Home gauge matches unified SleepRepository
            self.overrideSleepTrend(baseProps: p)
        }
        
        // Follow Polar battery/snapshots
        PolarManager.shared.onBatteryUpdate = { [weak self] deviceId, level, _ in
            guard let self else { return }
            self.pushBattery(self.isCalm360Connected ? Double(level) : nil)
        }
        
        PolarManager.shared.onSnapshot = { [weak self] snap in
            guard let self else { return }
            if self.isCalm360Connected {
                if let lvl = snap.batteryLevel {
                    self.pushBattery(Double(lvl))
                }
            } else {
                self.pushBattery(nil)
            }
        }
        
        polarObserverId = PolarManager.shared.addConnectionObserver { [weak self] state in
            guard let self else { return }
            if case .disconnected = state {
                self.pushBattery(nil)
            }
        }
    }
    
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
                    self.mapEmotionCategories(categories)
                    self.onEmotionDataLoaded?()

                case .Error(let message):
                    print("❌ Emotion tags fetch failed:", message)
                }
            }
        }
    }

    private func mapEmotionCategories(_ categories: [EmotionCategoryDTO]) {

        for category in categories {
            let mappedTags = category.tags.map {
                EmotionTag(
                    title: $0.name,
                    valence: $0.valence,
                    arousal: $0.arousal,
                    isSelected: false
                )
            }

            switch category.name.lowercased() {
            case "positive":
                positiveEmotions = mappedTags
            case "negative":
                negativeEmotions = mappedTags
            case "neutral":
                neutralEmotions = mappedTags
            case "cognitive":
                cognitiveEmotions = mappedTags
            default:
                break
            }
        }
    }
    
    private func handleUserUpdate() {
        guard let user = SessionManager.shared.current else { return }

        // For now: no-op
        // Future:
        // - plan flags
        // - greeting
        // - feature gating
        // - analytics identity
    }

    
    func stopLiveUpdates() {
        if let t = hubToken { CalmScoreHub.shared.removeListener(t) }
        hubToken = nil
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy • HH:mm"
        return df.string(from: date)
    }
    
    deinit {
        if let obs = userObserver {
                NotificationCenter.default.removeObserver(obs)
            }
        if let t = hubToken { CalmScoreHub.shared.removeListener(t) }
        if let id = polarObserverId { PolarManager.shared.removeConnectionObserver(id) }
        selectionTimers.values.forEach { $0.invalidate() }
        selectionTimers.removeAll()
        EmotionStore.shared.onChange = nil
    }
    
    // MARK: - Emotion handling (global)
    
    /// Toggle a chip with 60s auto-clear and publish global emotion → hub recomputes for all screens.
    func toggleEmotionSelection(at index: Int, for category: HomeViewController.EmotionCategory) {
        let timerKey = "\(category)-\(index)"
        let isNowSelected = toggleEmotionState(at: index, for: category)

        if isNowSelected {
            let emotion = emotionFor(category: category, index: index)
            postSessionEmotion(emotion: emotion)
        }

        if isNowSelected {
            selectionTimers[timerKey]?.invalidate()
            let timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.deselectEmotion(at: index, for: category)
                self.onEmotionDeselected?(category, index)
                self.selectionTimers.removeValue(forKey: timerKey)
            }
            selectionTimers[timerKey] = timer
        } else {
            selectionTimers[timerKey]?.invalidate()
            selectionTimers.removeValue(forKey: timerKey)
        }
    }
    
    private func emotionFor(
        category: HomeViewController.EmotionCategory,
        index: Int
    ) -> EmotionTag {
        switch category {
        case .positive: return positiveEmotions[index]
        case .negative: return negativeEmotions[index]
        case .neutral:  return neutralEmotions[index]
        case .cognitive:return cognitiveEmotions[index]
        }
    }
    
    // MARK: - Helpers (emotions)
    
    private func findFirstSelectedEmotion() -> EmotionTag? {
        if let e = positiveEmotions.first(where: { $0.isSelected }) { return e }
        if let e = negativeEmotions.first(where: { $0.isSelected }) { return e }
        if let e = neutralEmotions.first(where: { $0.isSelected }) { return e }
        if let e = cognitiveEmotions.first(where: { $0.isSelected }) { return e }
        return nil
    }
    
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
    
    // MARK: - Gauge sleep override (unified SleepRepository, matches Biometrics/SleepInsight)
    
    /// Use unified SleepRepository (Polar360 > Apple Health) for current and previous night sleep.
    private func overrideSleepTrend(baseProps p0: CalmScoreTileProps) {
        workQ.async { [weak self] in
            guard let self else { return }
            
            let now = Date()
            
            // Current night (latest) from unified repo
            let currentNight = SleepRepository.shared.latestNight()
            let currentHours = currentNight?.hours
            
            // Previous night using the same unified pipeline
            let prevAnchor = Calendar.current.date(byAdding: .day, value: -1, to: now)
                ?? now.addingTimeInterval(-86400)
            let prevNight = self.latestNightBefore(date: prevAnchor)
            let prevHours = prevNight?.hours
            
            var p = p0
            
            if let curH = currentHours {
                var t = p.trend
                t.sleepHours = curH
                if let prevH = prevHours {
                    t.sleepIsUp = (curH >= prevH)
                }
                p.trend = t
            }
            
            self.currentProps = p
            DispatchQueue.main.async {
                self.onPropsUpdate?(p)
            }
        }
    }
    
    // MARK: - Battery bubble support
    
    private func pushBattery(_ pct: Double?) {
        guard var p = currentProps else { return }
        if p.deviceSource == .calm360 {
            p.batteryPercent = pct
        } else {
            p.batteryPercent = nil   // no battery fill for other sources
        }
        self.currentProps = p
        self.onPropsUpdate?(p)
    }
    
    // MARK: - Unified sleep helper (same logic pattern as BiometricsViewModel)
    
    /// Find the last full sleep night strictly before the given anchor.
    private func latestNightBefore(date: Date) -> (date: Date, hours: Double)? {
        // Look 48h back from anchor for any segments
        let start = date.addingTimeInterval(-48 * 3600)
        let segs = SleepRepository.shared.unifiedSegments(from: start, to: date)
        guard let last = segs.last else { return nil }
        
        // Bucket to that night's "sleep day start"
        let bucket = SleepRepository.shared.sleepDayStart(for: last.start)
        let nextBucket = bucket.addingTimeInterval(24 * 3600)
        
        let nightSegs = SleepRepository.shared.unifiedSegments(from: bucket, to: nextBucket)
        let secs = nightSegs.reduce(0.0) {
            $0 + max(0.0, $1.end.timeIntervalSince($1.start))
        }
        return (bucket, secs / 3600.0)
    }
    
    private func postSessionEmotion(
        emotion: EmotionTag,
        trigger: String = "BeforeTrade",
        note: String? = nil
    ) {

        let params: [String: Any] = [
            "emotionTags": [emotion.title],
            "primaryEmotion": emotion.title,
        ]

        APIService().startService(
            with: .POST,
            path: "session/emotions",
            parameters: params,
            files: nil,
            modelType: SessionEmotionResponse.self
        ) { result in
            switch result {
            case .Success:
                break // fire-and-forget by design

            case .Error(let message):
                print("❌ session/emotions failed:", message)
            }
        }
    }
}
