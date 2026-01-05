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
        let end   = cal.date(byAdding: .day, value: 1, to: start)!

        guard api.isFeatureReady(deviceId, feature: .feature_polar_activity_data) else {
            NSLog("[PM][ACT] feature not ready; skipping fetch")
            completion([]); return
        }

        api.getActivitySampleData(identifier: deviceId, fromDate: start, toDate: end)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] days in
                guard let self else { completion([]); return }
                var out: [(Date, Int)] = []
                for dayObj in days {
                    out.append(contentsOf: self._extractMinutePairs(from: dayObj, dayStart: start))
                }
                out.sort { $0.0 < $1.0 }
                completion(out)
            }, onFailure: { err in
                NSLog("[PM][ACT] getActivitySampleData error: %@", err.localizedDescription)
                completion([])
            })
            .disposed(by: disposeBag)
    }

    /// Repo ingest (Polar 360 → .steps)
    func submitPolar360MinuteSteps(_ minutes: [(Date, Int)]) {
        guard !minutes.isEmpty else { return }
        let repo = CTMetricsRepository.shared
        for (ts, steps) in minutes {
            repo.upsert(kind: .steps, value: Double(steps), unit: "steps", source: .polar360, date: ts)
        }
        NotificationCenter.default.post(name: .ctMetricUpdated, object: nil,
                                        userInfo: ["kind": "steps", "date": Date()])
    }
}
