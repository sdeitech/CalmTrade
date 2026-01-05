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

    private func startHeartbeat() {
        heartbeat?.invalidate()
        heartbeat = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollAndMaybePublish()
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

        let hrLiveWindow: TimeInterval = 5
        let rmssdLiveWindow: TimeInterval = 15

        let hrH10 = repo.latestValue(kind: .heartRate, source: .polarH10)
        let hrP36 = repo.latestValue(kind: .heartRate, source: .polar360)
        let hrAny = repo.latestValue(kind: .heartRate)

        let rmssdH10 = repo.latestValue(kind: .rmssd, source: .polarH10)
        let rmssdP36 = repo.latestValue(kind: .rmssd, source: .polar360)
        let rmssdAny = repo.latestValue(kind: .rmssd)
        let sdnnHK = repo.latestValue(kind: .sdnn, source: .appleHealth)
        let hrvMs = (rmssdAny?.value ?? sdnnHK?.value) ?? 0

        let freshHR = freshestPolarHR(
            now: now,
            maxAgeSec: hrLiveWindow,
            h10: hrH10,
            p36: hrP36
        )

        let isStreaming = (freshHR != nil)

        var deviceSource: DeviceSource = {
            if let src = freshHR?.src { return src }
            let freshRmssdH10 = rmssdH10.flatMap { now.timeIntervalSince($0.date) <= rmssdLiveWindow ? $0 : nil }
            let freshRmssdP36 = rmssdP36.flatMap { now.timeIntervalSince($0.date) <= rmssdLiveWindow ? $0 : nil }
            if freshRmssdH10 != nil { return .h10 }
            if freshRmssdP36 != nil { return .calm360 }
            return .appleHK
        }()
        if !isStreaming { deviceSource = .appleHK }

        let hrBpm: Double = {
            switch deviceSource {
            case .h10:     return hrH10?.value ?? hrAny?.value ?? 0
            case .calm360: return hrP36?.value ?? hrAny?.value ?? 0
            default:       return hrAny?.value ?? 0
            }
        }()

        let sleepUnion = computeLastNightSleepHoursFromRepo(now: now)
        let sleepHours: Double = sleepUnion?.hours
            ?? (repo.latestValue(kind: .sleepHours)?.value ?? 0)

        let last2HRVals = lastTwoValues(kind: .heartRate)
        let last2HRVVals = (rmssdAny != nil
                            ? lastTwoValues(kind: .rmssd)
                            : lastTwoValues(kind: .sdnn))
        let last2SlpVals = lastTwoValues(kind: .sleepHours)

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
            rmssdH10?.date, rmssdP36?.date, rmssdAny?.date,
            sdnnHK?.date, hrAny?.date, sleepUnion?.endDate
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

    private func lastTwoValues(kind: CTMetricKind) -> [Double] {
        let repo = CTMetricsRepository.shared
        let now = Date()
        let from = now.addingTimeInterval(-24 * 3600)
        let samples = repo.seriesValues(kind: kind, from: from, to: now, source: nil)
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
    private func computeLastNightSleepHoursFromRepo(now: Date = Date()) -> (hours: Double, endDate: Date)? {
        let repo = CTMetricsRepository.shared
        let win = windowForLastNight(anchoredAt: now)
        let rem  = repo.seriesValues(kind: .sleepREM,  from: win.start, to: win.end, source: .appleHealth)
        let core = repo.seriesValues(kind: .sleepCore, from: win.start, to: win.end, source: .appleHealth)
        let deep = repo.seriesValues(kind: .sleepDeep, from: win.start, to: win.end, source: .appleHealth)

        if rem.isEmpty && core.isEmpty && deep.isEmpty { return nil }

        var intervals: [(Date, Date)] = []
        for s in rem + core + deep {
            let st = max(s.date, win.start)
            let en = min(s.date.addingTimeInterval(s.value), win.end)
            if en > st { intervals.append((st, en)) }
        }

        intervals.sort { $0.0 < $1.0 }
        var merged: [(Date, Date)] = []

        for (s, e) in intervals {
            guard s < e else { continue }
            if let last = merged.last, s <= last.1 {
                merged[merged.count - 1].1 = max(last.1, e)
            } else {
                merged.append((s, e))
            }
        }

        let seconds = merged.reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) }
        return (seconds / 3600.0, win.end)
    }

    private func windowForLastNight(anchoredAt now: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: now)
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart)!
        let start6pm = cal.date(byAdding: .hour, value: -18, to: noon)!
        return (start6pm, noon)
    }
}
