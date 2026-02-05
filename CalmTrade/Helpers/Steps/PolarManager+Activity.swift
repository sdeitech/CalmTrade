//
//  PolarManager+Activity.swift
//  CalmTrade
//
//  Created by Anas Parekh on 23/10/25.
//

// MARK: - Polar 360 Activity: minute-steps fetch + ingest
import RxSwift

extension PolarManager {

    /// Strong, schema-agnostic extractor for minute samples.
    /// Supports two common shapes in Polar SDKs:
    ///  A) [ { timestamp: Date, steps: Int } ]
    ///  B) [ { secondsFromStart: Int, steps: Int } ] + parent day start
    private func _extractMinutePairs(from dayObj: Any, dayStart: Date) -> [(Date, Int)] {
        var out: [(Date, Int)] = []

        // Find "samples" array on the day object
        let dayMirror = Mirror(reflecting: dayObj)
        let samplesAny = dayMirror.children.first { label, _ in
            label?.lowercased().contains("sample") == true
        }?.value

        guard let samples = samplesAny as? [Any] else { return out }

        for s in samples {
            let m = Mirror(reflecting: s)

            // 1) timestamp: Date
            let tsDate = (m.children.first { $0.label?.lowercased().contains("time") == true }?.value as? Date)
                      ?? (m.children.first { $0.label?.lowercased().contains("timestamp") == true }?.value as? Date)

            // 2) seconds offset (if present)
            let seconds = (m.children.first { $0.label?.lowercased().contains("second") == true }?.value as? Int)
                       ?? (m.children.first { $0.label?.lowercased().contains("second") == true }?.value as? UInt).map { Int($0) }

            let steps = (m.children.first { $0.label?.lowercased().contains("step") == true }?.value as? Int)
                     ?? (m.children.first { $0.label?.lowercased().contains("step") == true }?.value as? UInt).map { Int($0) }

            guard let st = steps, st > 0 else { continue }

            if let tsDate { out.append((tsDate, st)) }
            else if let seconds { out.append((dayStart.addingTimeInterval(TimeInterval(seconds)), st)) }
        }
        return out
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

        // Use the dedicated getSteps method like in the reference implementation
        self.api.getSteps(identifier: deviceId, fromDate: start, toDate: end)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] days in
                guard let self else {
                    debugPrint("=== PolarManager+Activity ===")
                    debugPrint("Self was nil in success callback")
                    debugPrint("=============================")
                    completion([]);
                    return
                }

                debugPrint("=== PolarManager+Activity ===")
                debugPrint("Successfully fetched \(days.count) days of Polar steps data")

                var out: [(Date, Int)] = []
                for dayObj in days {
                    let extracted = self._extractMinutePairs(from: dayObj, dayStart: start)
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

                completion(out)
            }, onFailure: { err in
                debugPrint("=== PolarManager+Activity ===")
                debugPrint("Failed to fetch Polar steps via getSteps: \(err.localizedDescription)")
                debugPrint("=============================")

                // Fallback to the older method
                debugPrint("Falling back to getActivitySampleData method...")

                self.api.getActivitySampleData(identifier: deviceId, fromDate: start, toDate: end)
                    .observe(on: MainScheduler.instance)
                    .subscribe(onSuccess: { [weak self] days in
                        guard let self else {
                            debugPrint("=== PolarManager+Activity Fallback ===")
                            debugPrint("Self was nil in fallback success callback")
                            debugPrint("=============================")
                            completion([]);
                            return
                        }

                        debugPrint("=== PolarManager+Activity Fallback ===")
                        debugPrint("Successfully fetched \(days.count) days of Polar activity data via fallback")

                        var out: [(Date, Int)] = []
                        for dayObj in days {
                            let extracted = self._extractMinutePairs(from: dayObj, dayStart: start)
                            debugPrint("Extracted \(extracted.count) step records from day object")
                            out.append(contentsOf: extracted)
                        }
                        out.sort { $0.0 < $1.0 }

                        debugPrint("Total extracted steps records from fallback: \(out.count)")

                        completion(out)
                    }, onFailure: { err in
                        debugPrint("=== PolarManager+Activity Fallback ===")
                        debugPrint("Also failed to fetch via getActivitySampleData: \(err.localizedDescription)")
                        debugPrint("=============================")

                        NSLog("[PM][ACT] fallback getActivitySampleData error: %@", err.localizedDescription)
                        completion([])
                    })
                    .disposed(by: self.disposeBag)
            })
            .disposed(by: disposeBag)
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
            repo.upsert(kind: .steps, value: Double(steps), unit: "steps", source: .polar360, date: ts)
        }
        NotificationCenter.default.post(name: .ctMetricUpdated, object: nil,
                                        userInfo: ["kind": "steps", "date": Date()])
    }
}
