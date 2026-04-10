//
//  PolarManager+Activity.swift
//  CalmTrade
//
//  Created by Anas Parekh on 23/10/25.
//

// MARK: - Polar 360 Activity: minute-steps fetch + ingest
import PolarBleSdk
import RxSwift

extension PolarManager {

    private var activityScheduler: ConcurrentDispatchQueueScheduler {
        ConcurrentDispatchQueueScheduler(qos: .utility)
    }

    private func _minuteFloor(_ date: Date) -> Date {
        Calendar.current.date(bySetting: .second, value: 0, of: date) ?? date
    }

    private func _extractMinutePairs(from activityDayData: PolarActivityDayData) -> [(Date, Int)] {
        var aggregated: [Date: Int] = [:]

        for dayData in activityDayData.polarActivityDataList {
            guard let samples = dayData.samples else { continue }

            let interval = max(1, samples.stepRecordingInterval)
            let start = samples.startTime
            let stepSamples = samples.stepSamples ?? []

            for (idx, rawSteps) in stepSamples.enumerated() {
                let steps = Int(rawSteps)
                guard steps > 0 else { continue }

                let ts = start.addingTimeInterval(TimeInterval(idx * interval))
                let minute = _minuteFloor(ts)
                aggregated[minute, default: 0] += steps
            }
        }

        return aggregated.keys.sorted().map { ($0, aggregated[$0] ?? 0) }
    }

    /// Strong, schema-agnostic extractor for minute samples.
    /// Supports two common shapes in Polar SDKs:
    ///  A) [ { timestamp: Date, steps: Int } ]
    ///  B) [ { secondsFromStart: Int, steps: Int } ] + parent day start
    private func _extractMinutePairs(from dayObj: Any, dayStart: Date) -> [(Date, Int)] {
        var minutePairs: [(Date, Int)] = []
        var sampleObjects: [Any] = []
        var dayLevelTotals: [Int] = []
        var stepSamplesSeries: [Int] = []
        var dayStartCandidate: Date?
        var stepIntervalSeconds: Int?

        func minuteFloor(_ date: Date) -> Date {
            Calendar.current.date(bySetting: .second, value: 0, of: date) ?? date
        }

        func intValue(_ any: Any) -> Int? {
            if let v = any as? Int { return v }
            if let v = any as? UInt { return Int(v) }
            if let v = any as? UInt32 { return Int(v) }
            if let v = any as? UInt64 { return Int(v) }
            if let v = any as? Double { return Int(v.rounded()) }
            if let v = any as? Float { return Int(v.rounded()) }
            if let v = any as? NSNumber { return v.intValue }
            return nil
        }

        func dateValue(_ any: Any) -> Date? {
            if let d = any as? Date { return d }
            return nil
        }

        func intArrayValue(_ any: Any) -> [Int] {
            if let arr = any as? [Int] { return arr }
            if let arr = any as? [UInt] { return arr.map { Int($0) } }
            if let arr = any as? [UInt32] { return arr.map { Int($0) } }
            if let arr = any as? [NSNumber] { return arr.map(\.intValue) }
            return []
        }

        func walk(_ any: Any, depth: Int) {
            guard depth <= 5 else { return }

            let mirror = Mirror(reflecting: any)
            if mirror.displayStyle == .optional {
                if let child = mirror.children.first { walk(child.value, depth: depth + 1) }
                return
            }

            for child in mirror.children {
                guard let rawLabel = child.label else { continue }
                let label = rawLabel.lowercased()
                let value = child.value

                if dayStartCandidate == nil,
                   (label.contains("starttime") ||
                    label == "start" ||
                    label.contains("start_date") ||
                    label == "date"),
                   let d = dateValue(value) {
                    dayStartCandidate = d
                }

                if stepIntervalSeconds == nil,
                   (label.contains("steprecordinginterval") ||
                    (label.contains("step") && label.contains("interval"))),
                   let interval = intValue(value), interval > 0 {
                    stepIntervalSeconds = interval
                }

                if label.contains("stepsamples") {
                    let arr = intArrayValue(value)
                    if !arr.isEmpty { stepSamplesSeries = arr }
                }

                if label.contains("sample"), let arr = value as? [Any], !arr.isEmpty {
                    sampleObjects.append(contentsOf: arr)
                }

                if label.contains("step"), !label.contains("sample"), let v = intValue(value), v > 0 {
                    dayLevelTotals.append(v)
                }

                walk(value, depth: depth + 1)
            }
        }

        walk(dayObj, depth: 0)

        let baseStart = dayStartCandidate ?? dayStart

        for sample in sampleObjects {
            let m = Mirror(reflecting: sample)
            var sampleDate: Date?
            var sampleSecondOffset: Int?
            var sampleSteps: Int?

            for c in m.children {
                guard let rawLabel = c.label else { continue }
                let label = rawLabel.lowercased()
                let value = c.value

                if sampleDate == nil && (label.contains("time") || label.contains("timestamp")) {
                    sampleDate = dateValue(value)
                }
                if sampleSecondOffset == nil && (label.contains("second") || label.contains("offset")) {
                    sampleSecondOffset = intValue(value)
                }
                if sampleSteps == nil && label.contains("step") {
                    sampleSteps = intValue(value)
                }
            }

            guard let st = sampleSteps, st > 0 else { continue }
            if let ts = sampleDate {
                minutePairs.append((minuteFloor(ts), st))
            } else if let sec = sampleSecondOffset {
                let ts = baseStart.addingTimeInterval(TimeInterval(sec))
                minutePairs.append((minuteFloor(ts), st))
            }
        }

        if minutePairs.isEmpty, !stepSamplesSeries.isEmpty {
            let interval = max(1, stepIntervalSeconds ?? 60)
            for (idx, steps) in stepSamplesSeries.enumerated() where steps > 0 {
                let ts = baseStart.addingTimeInterval(TimeInterval(idx * interval))
                minutePairs.append((minuteFloor(ts), steps))
            }
        }

        if minutePairs.isEmpty, let total = dayLevelTotals.filter({ $0 > 0 }).max() {
            // Some Polar payloads expose only day cumulative steps.
            minutePairs.append((minuteFloor(dayStart), total))
        }

        var aggregated: [Date: Int] = [:]
        for (ts, steps) in minutePairs {
            guard steps > 0 else { continue }
            aggregated[ts, default: 0] += steps
        }
        return aggregated.keys.sorted().map { ($0, aggregated[$0] ?? 0) }
    }

    /// Public: fetch Polar 360 minute steps for a given civil day.
    func fetchPolarActivity(deviceId: String, date: Date,
                            completion: @escaping ([(Date, Int)]) -> Void)
    {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-1) // End of day (23:59:59)

        debugPrint("=== PolarManager+Activity ===")
        debugPrint("Fetching Polar steps for date: \(date) (range: \(start) to \(end))")
        debugPrint("=============================")

        guard self.api.isFeatureReady(deviceId, feature: .feature_polar_activity_data) else {
            NSLog("[PM][ACT] feature not ready; skipping fetch")
            completion([]); return
        }

        // Minute-level live-ish step updates come from activity samples, not getSteps.
        // `getSteps` returns an accumulated total per day, which collapses to midnight in the UI.
        self.api.getActivitySampleData(identifier: deviceId, fromDate: start, toDate: end)
            .subscribe(on: activityScheduler)
            .observe(on: activityScheduler)
            .subscribe(onSuccess: { [weak self] dayDataList in
                guard let self else {
                    debugPrint("=== PolarManager+Activity ===")
                    debugPrint("Self was nil in success callback")
                    debugPrint("=============================")
                    completion([]);
                    return
                }

                debugPrint("=== PolarManager+Activity ===")
                debugPrint("Successfully fetched \(dayDataList.count) days of Polar activity sample data")

                var out: [(Date, Int)] = []
                for dayData in dayDataList {
                    let extracted = self._extractMinutePairs(from: dayData as PolarActivityDayData)
                    debugPrint("Extracted \(extracted.count) step records from day object")
                    out.append(contentsOf: extracted)
                }
                out.sort { $0.0 < $1.0 }

                debugPrint("Total extracted steps records: \(out.count)")
                for (ts, steps) in out.prefix(5) {
                    debugPrint("  - \(ts) : \(steps) steps")
                }
                if out.count > 5 {
                    debugPrint("  ... and \(out.count - 5) more records")
                }
                debugPrint("=============================")

                DispatchQueue.main.async {
                    completion(out)
                }
            }, onFailure: { err in
                debugPrint("=== PolarManager+Activity ===")
                debugPrint("Failed to fetch minute samples via getActivitySampleData: \(err.localizedDescription)")
                debugPrint("=============================")

                // Fallback: at least keep a daily total if minute samples are unavailable.
                debugPrint("Falling back to getSteps daily total method...")

                self.api.getSteps(identifier: deviceId, fromDate: start, toDate: end)
                    .subscribe(on: self.activityScheduler)
                    .observe(on: self.activityScheduler)
                    .subscribe(onSuccess: { [weak self] days in
                        guard let self else {
                            debugPrint("=== PolarManager+Activity Fallback ===")
                            debugPrint("Self was nil in fallback success callback")
                            debugPrint("=============================")
                            completion([]);
                            return
                        }

                        debugPrint("=== PolarManager+Activity Fallback ===")
                        debugPrint("Successfully fetched \(days.count) days of Polar steps totals via fallback")

                        var out: [(Date, Int)] = []
                        for dayObj in days {
                            let extracted = self._extractMinutePairs(from: dayObj, dayStart: start)
                            debugPrint("Extracted \(extracted.count) step records from day object")
                            out.append(contentsOf: extracted)
                        }
                        out.sort { $0.0 < $1.0 }

                        debugPrint("Total extracted steps records from fallback: \(out.count)")

                        DispatchQueue.main.async {
                            completion(out)
                        }
                    }, onFailure: { err in
                        debugPrint("=== PolarManager+Activity Fallback ===")
                        debugPrint("Also failed to fetch via getSteps: \(err.localizedDescription)")
                        debugPrint("=============================")

                        NSLog("[PM][ACT] fallback getSteps error: %@", err.localizedDescription)
                        DispatchQueue.main.async {
                            completion([])
                        }
                    })
                    .disposed(by: self.disposeBag)
            })
            .disposed(by: disposeBag)
    }

    /// Public: fetch Polar 360 current daily total, which updates faster than minute samples.
    func fetchPolarLiveStepsTotal(deviceId: String,
                                  date: Date = Date(),
                                  completion: @escaping (Int?) -> Void)
    {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = start

        guard self.api.isFeatureReady(deviceId, feature: .feature_polar_activity_data) else {
            NSLog("[PM][ACT] feature not ready; skipping live total fetch")
            completion(nil)
            return
        }

        self.api.getSteps(identifier: deviceId, fromDate: start, toDate: end)
            .subscribe(on: activityScheduler)
            .observe(on: activityScheduler)
            .subscribe(onSuccess: { days in
                let total = days
                    .filter { Calendar.current.isDate($0.date, inSameDayAs: start) }
                    .map(\.steps)
                    .max()

                if let total {
                    debugPrint("[PM][ACT] live total fetched: \(total) steps")
                } else {
                    debugPrint("[PM][ACT] live total fetch returned no steps")
                }
                DispatchQueue.main.async {
                    completion(total)
                }
            }, onFailure: { err in
                NSLog("[PM][ACT] live total fetch error: %@", err.localizedDescription)
                DispatchQueue.main.async {
                    completion(nil)
                }
            })
            .disposed(by: disposeBag)
    }

    /// Ask the device to flush the latest activity data, then read today's total + minute samples.
    func refreshPolarTodayActivity(deviceId: String,
                                   completion: @escaping (_ totalSteps: Int?, _ minutes: [(Date, Int)]) -> Void)
    {
        func finish(_ total: Int?, _ minutes: [(Date, Int)]) {
            self.api.sendTerminateAndStopSyncNotifications(identifier: deviceId)
                .subscribe(on: self.activityScheduler)
                .observe(on: self.activityScheduler)
                .subscribe(onCompleted: {
                    DispatchQueue.main.async {
                        completion(total, minutes)
                    }
                }, onError: { err in
                    NSLog("[PM][ACT] stop sync error: %@", err.localizedDescription)
                    DispatchQueue.main.async {
                        completion(total, minutes)
                    }
                })
                .disposed(by: self.disposeBag)
        }

        self.api.sendInitializationAndStartSyncNotifications(identifier: deviceId)
            .subscribe(on: activityScheduler)
            .observe(on: activityScheduler)
            .subscribe(onCompleted: { [weak self] in
                guard let self else {
                    DispatchQueue.main.async {
                        completion(nil, [])
                    }
                    return
                }

                self.fetchPolarLiveStepsTotal(deviceId: deviceId) { total in
                    self.fetchPolarActivity(deviceId: deviceId, date: Date()) { minutes in
                        finish(total, minutes)
                    }
                }
            }, onError: { [weak self] err in
                NSLog("[PM][ACT] start sync error: %@", err.localizedDescription)
                self?.fetchPolarLiveStepsTotal(deviceId: deviceId) { total in
                    self?.fetchPolarActivity(deviceId: deviceId, date: Date()) { minutes in
                        completion(total, minutes)
                    }
                } ?? completion(nil, [])
            })
            .disposed(by: disposeBag)
    }

    /// Apply today's cumulative Polar total as a near-live update for the current minute.
    /// This fills the UI gap until exact minute samples are written by getActivitySampleData.
    func submitPolar360LiveStepsTotal(_ totalSteps: Int, asOf now: Date = Date()) {
        guard totalSteps > 0 else { return }

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: now)
        let minuteStart = _minuteFloor(now)
        let minuteEnd = cal.date(byAdding: .minute, value: 1, to: minuteStart) ?? now.addingTimeInterval(60)
        let repo = CTMetricsRepository.shared

        let todayTotalInRepo = repo.series(kind: .steps, from: startOfDay, to: now, source: .polar360)
            .reduce(0) { $0 + Int($1.value.rounded()) }

        let missing = totalSteps - todayTotalInRepo
        guard missing > 0 else {
            debugPrint("[PM][ACT] live total has no missing delta (sdk=\(totalSteps), repo=\(todayTotalInRepo))")
            return
        }

        let currentMinuteValue = repo.series(kind: .steps, from: minuteStart, to: minuteEnd, source: .polar360)
            .reduce(0) { $0 + Int($1.value.rounded()) }

        let newMinuteValue = currentMinuteValue + missing

        debugPrint("[PM][ACT] applying live delta missing=\(missing) minuteStart=\(minuteStart) newMinuteValue=\(newMinuteValue)")

        repo.upsert(
            kind: .steps,
            value: Double(newMinuteValue),
            unit: "steps",
            source: .polar360,
            date: minuteStart,
            notifyMirror: false
        )

        NotificationCenter.default.post(
            name: .ctMetricUpdated,
            object: nil,
            userInfo: ["kind": "steps", "date": minuteStart]
        )
        NotificationCenter.default.post(name: .ctMetricsDidMirror, object: nil)
    }

    /// Repo ingest (Polar 360 → .steps)
    func submitPolar360MinuteSteps(_ minutes: [(Date, Int)]) {
        guard !minutes.isEmpty else {
            debugPrint("=== PolarManager+Activity ===")
            debugPrint("No Polar steps data to submit")
            debugPrint("=============================")
            return
        }

        debugPrint("=== PolarManager+Activity ===")
        debugPrint("Submitting \(minutes.count) Polar 360 step entries to repository")
        for (ts, steps) in minutes.prefix(5) { // Print first 5 entries as sample
            debugPrint("  - \(ts) : \(steps) steps")
        }
        if minutes.count > 5 {
            debugPrint("  ... and \(minutes.count - 5) more entries")
        }
        debugPrint("=============================")

        let repo = CTMetricsRepository.shared
        for (ts, steps) in minutes {
            repo.upsert(
                kind: .steps,
                value: Double(steps),
                unit: "steps",
                source: .polar360,
                date: ts,
                notifyMirror: false
            )
        }
        NotificationCenter.default.post(name: .ctMetricUpdated, object: nil,
                                        userInfo: ["kind": "steps", "date": Date()])
        NotificationCenter.default.post(name: .ctMetricsDidMirror, object: nil)
    }
}
