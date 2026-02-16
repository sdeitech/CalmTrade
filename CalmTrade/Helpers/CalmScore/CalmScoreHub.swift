//
//  CalmScoreHub.swift
//  CalmTrade
//
//  Recomputes CalmScore whenever local metrics change.
//  Pure physiological CalmScore (no emotions, no edge).
//  Per-user aware (scopes all data and listeners to current logged-in user).
//

import Foundation

// MARK: - Notification names
extension Notification.Name {
    static let ctMetricUpdated   = Notification.Name("ctMetricUpdated")
}

final class CalmScoreHub {
    static let shared = CalmScoreHub()
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onUserChanged),
            name: .userAccountDidChange,
            object: nil
        )
    }

    // MARK: - Calculator
    private let calculator = CalmScoreCalculator()

    // MARK: - Listener management
    typealias Listener = (_ session: CalmScoreSession, _ inputs: CalmScoreBiometricInputs, _ props: CalmScoreTileProps) -> Void
    private var listeners: [UUID: Listener] = [:]

    var onScore: ((CalmScoreSession) -> Void)?

    deinit {
        // Clean up resources when hub is deallocated
        stop()
        NotificationCenter.default.removeObserver(self)
    }

    private var isStarted = false
    private var observeTokens: [NSObjectProtocol] = []
    private var currentPhase: CalmScorePhase = .during
    private var heartbeat: Timer?
    private var lastSignature: String?

    // MARK: - Public API
    func start(phase: CalmScorePhase = .during) {
        guard !isStarted else { return }
        isStarted = true
        currentPhase = phase

        publish(phase: phase)
        attachObservers(for: phase)
        startHeartbeat()
    }

    func stop() {
        observeTokens.forEach { NotificationCenter.default.removeObserver($0) }
        observeTokens.removeAll()
        heartbeat?.invalidate()
        heartbeat = nil
        isStarted = false
    }

    @objc private func onUserChanged() {
        listeners.removeAll()
        lastSignature = nil
        stop()
        isStarted = false

        CalmScoreStore.shared.purgeOldSessionCache()

        start(phase: currentPhase)
    }

    private func attachObservers(for phase: CalmScorePhase) {

        // Mirror (bulk update)
        let tok1 = NotificationCenter.default.addObserver(
            forName: .ctMetricsDidMirror, object: nil, queue: .main
        ) { [weak self] _ in self?.publish(phase: phase) }

        // Individual metric updates
        let tok2 = NotificationCenter.default.addObserver(
            forName: .ctMetricUpdated, object: nil, queue: .main
        ) { [weak self] note in
            guard let kind = note.userInfo?["kind"] as? String else {
                self?.publish(phase: phase)
                return
            }
            if kind == "rmssd" || kind == "sdnn" || kind == "heartRate" || kind == "sleep" {
                self?.publish(phase: phase)
            }
        }

        observeTokens.append(contentsOf: [tok1, tok2])
    }

    private var lastActiveTime: Date = Date()
    private let heartbeatInterval: TimeInterval = 1.0
    private let inactiveTimeout: TimeInterval = 300 // 5 minutes of inactivity before reducing heartbeat

    private func startHeartbeat() {
        heartbeat?.invalidate()
        heartbeat = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            self?.pollAndMaybePublish()
            self?.lastActiveTime = Date() // Update last active time with each poll
        }
    }

    // MARK: - Poll + publish
    private func pollAndMaybePublish() {
        let inputs  = LatestBiometricsCache.shared.snapshot()
        let session = calculator.session(from: inputs, phase: currentPhase)
        let props   = makeProps(from: session, inputs: inputs)

        let sig = signature(for: session, props: props)
        guard sig != lastSignature else { return }
        lastSignature = sig

        CalmScoreStore.shared.save(
            value: session.calmScore,
            at: props.lastUpdate,
            source: String(describing: props.deviceSource)
        )

        onScore?(session)

        for cb in listeners.values {
            DispatchQueue.main.async { cb(session, inputs, props) }
        }
    }

    private func signature(for session: CalmScoreSession, props: CalmScoreTileProps) -> String {
        [
            "\(Int(session.calmScore))",
            "\(Int(props.trend.hrBpm.rounded()))",
            props.deviceSource.rawValue,
            props.isStreaming ? "1" : "0",
            "\(Int(props.lastUpdate.timeIntervalSince1970))",
            "\(Int(props.trend.sleepHours.rounded()))"
        ].joined(separator: "|")
    }

    // MARK: - Listener registration
    @discardableResult
    func addListener(_ listener: @escaping Listener, phase: CalmScorePhase = .during) -> UUID {
        let id = UUID()
        listeners[id] = listener
        start(phase: phase)

        let inputs  = LatestBiometricsCache.shared.snapshot()
        let session = calculator.session(from: inputs, phase: phase)
        let props   = makeProps(from: session, inputs: inputs)

        CalmScoreStore.shared.save(
            value: session.calmScore,
            at: props.lastUpdate,
            source: String(describing: props.deviceSource)
        )

        DispatchQueue.main.async { listener(session, inputs, props) }
        return id
    }

    func removeListener(_ id: UUID) {
        listeners.removeValue(forKey: id)
    }

    // MARK: - Core publish
    private func publish(phase: CalmScorePhase) {
        DispatchQueue.main.async {
            let inputs = LatestBiometricsCache.shared.snapshot()
            let session = self.calculator.session(from: inputs, phase: phase)
            let debug = self.calculator.debugMetrics(from: inputs)

            let entry = CalmScoreDiagnosticEntry(
                timestamp: Date(),
                inputs: inputs,
                zHRV: debug.zHRV,
                zHR: debug.zHR,
                zRHR: debug.zRHR,
                zSleep: debug.zSlp,
                contribHRV: debug.contribHRV,
                contribHR: debug.contribHR,
                contribRHR: debug.contribRHR,
                contribSleep: debug.contribSlp,
                finalScore: session.calmScore,
                summary: DiagnosticsSummaryBuilder.build(from: debug)
            )

            CalmScoreDiagnosticsStore.shared.add(entry)
            let props = self.makeProps(from: session, inputs: inputs)

            CalmScoreStore.shared.save(
                value: session.calmScore,
                at: props.lastUpdate,
                source: String(describing: props.deviceSource)
            )

            SocketClient.shared.send(key: "save_calmscore", payload: [
                "value": session.calmScore,
                "sourceDevice": props.deviceSource.rawValue
            ])

            self.onScore?(session)
            for cb in self.listeners.values {
                cb(session, inputs, props)
            }
        }
    }

    // MARK: - Props builder
    private func makeProps(from session: CalmScoreSession, inputs: CalmScoreBiometricInputs) ->
        CalmScoreTileProps {

        let repo = CTMetricsRepository.shared
        let now = Date()
        let polarPreferred: Bool = {
            switch DeviceManager.shared.currentSource {
            case .polar360, .polarH10: return true
            case .appleHealthKit: return false
            }
        }()

        let hrLiveWindow: TimeInterval = 5
        let rmssdLiveWindow: TimeInterval = 15

        let hrH10 = repo.latestValue(kind: .heartRate, source: .polarH10)
        let hrP36 = repo.latestValue(kind: .heartRate, source: .polar360)
        let hrHK = repo.latestValue(kind: .heartRate, source: .appleHealth)

        let rmssdH10 = repo.latestValue(kind: .rmssd, source: .polarH10)
        let rmssdP36 = repo.latestValue(kind: .rmssd, source: .polar360)
        let rmssdHK = repo.latestValue(kind: .rmssd, source: .appleHealth)
        let sdnnHK = repo.latestValue(kind: .sdnn, source: .appleHealth)
        let hrvMs = polarPreferred
            ? (rmssdH10?.value ?? rmssdP36?.value ?? 0)
            : (rmssdHK?.value ?? sdnnHK?.value ?? 0)

        let freshHR = freshestPolarHR(
            now: now,
            maxAgeSec: hrLiveWindow,
            h10: hrH10,
            p36: hrP36
        )

        let isStreaming = (freshHR != nil)

        var deviceSource: DeviceSource = {
            if !polarPreferred { return .appleHK }
            if let src = freshHR?.src { return src }
            let freshRmssdH10 = rmssdH10.flatMap { now.timeIntervalSince($0.date) <= rmssdLiveWindow ? $0 : nil }
            let freshRmssdP36 = rmssdP36.flatMap { now.timeIntervalSince($0.date) <= rmssdLiveWindow ? $0 : nil }
            if freshRmssdH10 != nil { return .h10 }
            if freshRmssdP36 != nil { return .calm360 }
            return .appleHK
        }()
        if !polarPreferred { deviceSource = .appleHK }

        let hrBpm: Double = {
            switch deviceSource {
            case .h10:     return hrH10?.value ?? (polarPreferred ? 0 : (hrHK?.value ?? 0))
            case .calm360: return hrP36?.value ?? (polarPreferred ? 0 : (hrHK?.value ?? 0))
            default:       return hrHK?.value ?? 0
            }
        }()

        let sleepUnion = computeLastNightSleepHoursFromRepo(now: now, preferredSource: polarPreferred ? .ct360 : .appleHealth)
        let sleepHours: Double = sleepUnion?.hours
            ?? (repo.latestValue(kind: .sleepHours, source: polarPreferred ? .polar360 : .appleHealth)?.value ?? 0)

        let trendSource: CTMetricSource? = polarPreferred ? .polar360 : .appleHealth
        let last2HRVals = lastTwoValues(kind: .heartRate, source: trendSource)
        let last2HRVVals = ((polarPreferred ? (rmssdH10 != nil || rmssdP36 != nil) : (rmssdHK != nil))
                            ? lastTwoValues(kind: .rmssd, source: trendSource)
                            : lastTwoValues(kind: .sdnn, source: .appleHealth))
        let last2SlpVals = lastTwoValues(kind: .sleepHours, source: trendSource)

        let hrIsDown = (last2HRVals.count == 2)
                       ? (last2HRVals[1] <= last2HRVals[0])
                       : true

        let hrvIsUp = (last2HRVVals.count == 2)
                      ? (last2HRVVals[1] >= last2HRVVals[0])
                      : true

        let sleepIsUp = (last2SlpVals.count == 2)
                        ? (last2SlpVals[1] >= last2SlpVals[0])
                        : true

        let lastUpdate = [
            freshHR?.latest.date,
            rmssdH10?.date, rmssdP36?.date, rmssdHK?.date,
            sdnnHK?.date, hrHK?.date, sleepUnion?.endDate
        ].compactMap { $0 }.max() ?? now

        return CalmScoreTileProps(
            score: Double(Int(session.calmScore)),
            lastUpdate: lastUpdate,
            deviceSource: deviceSource,
            isStreaming: isStreaming,
            trend: TrendData(
                hrvMs: Double(Int(hrvMs)),
                hrvIsUp: hrvIsUp,
                hrBpm: Double(Int(hrBpm)),
                hrIsDown: hrIsDown,
                sleepHours: sleepHours,
                sleepIsUp: sleepIsUp
            )
        )
    }

    // MARK: - Helpers
    private typealias Latest = CTMetricsRepository.CTBiometricLatest

    private func lastTwoValues(kind: CTMetricKind, source: CTMetricSource?) -> [Double] {
        let repo = CTMetricsRepository.shared
        let now = Date()
        let from = now.addingTimeInterval(-24 * 3600)
        let samples = repo.seriesValues(kind: kind, from: from, to: now, source: source)
        return samples.suffix(2).map { $0.value }
    }

    private func freshestPolarHR(
        now: Date,
        maxAgeSec: TimeInterval,
        h10: CTMetricsRepository.CTBiometricLatest?,
        p36: CTMetricsRepository.CTBiometricLatest?
    ) -> (latest: CTMetricsRepository.CTBiometricLatest, src: DeviceSource)? {

        func fresh(_ s: CTMetricsRepository.CTBiometricLatest?) -> CTMetricsRepository.CTBiometricLatest? {
            guard let s else { return nil }
            return now.timeIntervalSince(s.date) <= maxAgeSec ? s : nil
        }

        let fh10 = fresh(h10)
        let fp36 = fresh(p36)

        if let a = fh10, let b = fp36 {
            return (a.date >= b.date) ? (a, .h10) : (b, .calm360)
        } else if let a = fh10 {
            return (a, .h10)
        } else if let b = fp36 {
            return (b, .calm360)
        } else {
            return nil
        }
    }

    // MARK: - Sleep helper
    private func computeLastNightSleepHoursFromRepo(
        now: Date = Date(),
        preferredSource: SleepDataSource
    ) -> (hours: Double, endDate: Date)? {
        guard let night = SleepRepository.shared.latestNight(preferredSource: preferredSource) else { return nil }
        let endDate = night.segments.map(\.end).max() ?? night.date
        return (night.hours, endDate)
    }

    private func windowForLastNight(anchoredAt now: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: now)
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart)!
        let start6pm = cal.date(byAdding: .hour, value: -18, to: noon)!
        return (start6pm, noon)
    }
}
