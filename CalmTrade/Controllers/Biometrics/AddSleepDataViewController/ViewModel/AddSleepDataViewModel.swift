//
//  AddSleepDataViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/09/25.
//  UPDATED: No HealthKit writes — persist to local CTMetricsRepository.
//

import Foundation
import UIKit

final class AddSleepDataViewModel {

    // MARK: - Properties (UI inputs)
    var startTime: Date = Calendar.current.date(bySettingHour: 22, minute: 30, second: 0, of: Date())!
    var endTime: Date   = Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: Date())!

    /// The “wake-up day” selected in the UI (same semantics as before).
    var sleepDate: Date = Date()

    // MARK: - Private
    private let repo = CTMetricsRepository.shared

    // MARK: - Computed Properties
    var totalSleepTimeString: NSAttributedString {
        let duration = resolvedDurationSeconds()
        let totalMinutes = max(0, Int(duration) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        let boldFont = UIFont.boldSystemFont(ofSize: 48)
        let regularFont = UIFont.systemFont(ofSize: 24)

        let s = NSMutableAttributedString()
        s.append(NSAttributedString(string: "\(hours)", attributes: [.font: boldFont]))
        s.append(NSAttributedString(string: " hr ", attributes: [.font: regularFont]))
        s.append(NSAttributedString(string: "\(minutes)", attributes: [.font: regularFont]))
        s.append(NSAttributedString(string: " min", attributes: [.font: regularFont]))
        return s
    }

    // MARK: - Public Methods

    /// Saves the selected sleep time range to **local storage** (no HealthKit write).
    /// - Persists as a `.sleepHours` sample with `date = end` and `value = hours`.
    func saveSleepData(completion: @escaping (Bool, Error?) -> Void) {
        let cal = Calendar.current
        let startComponents = cal.dateComponents([.hour, .minute], from: startTime)
        let endComponents   = cal.dateComponents([.hour, .minute],   from: endTime)

        guard let sHour = startComponents.hour,
              let sMin  = startComponents.minute,
              let eHour = endComponents.hour,
              let eMin  = endComponents.minute
        else {
            return completion(false, makeError("Invalid time components"))
        }

        var finalEnd = cal.date(bySettingHour: eHour, minute: eMin, second: 0, of: sleepDate)!
        var finalStart = cal.date(bySettingHour: sHour, minute: sMin, second: 0, of: sleepDate)!

        // Overnight logic: if start is “later” than end, sleep started the **previous** day.
        if finalStart > finalEnd {
            finalStart = cal.date(byAdding: .day, value: -1, to: finalStart)!
        }

        let duration = finalEnd.timeIntervalSince(finalStart)
        let durationSec = duration > 0 ? duration : (duration + 24 * 3600) // extra safety
        let hours = durationSec / 3600.0

        // Guard against zero/negative or absurd entries
        guard hours.isFinite, hours > 0, hours <= 24 else {
            return completion(false, makeError("Sleep duration must be between 1 minute and 24 hours."))
        }

        // Persist to LOCAL store (app’s single source of truth)
        // Note: Using `.appleHealth` provenance keeps it visually grouped with HK-derived sleep
        // while still avoiding any HK writes.
        _ = repo.save(kind: .sleepHours,
                      value: hours,
                      unit: "h",
                      source: .appleHealth,
                      date: finalEnd)

        // Repo posts .ctMetricsDidMirror; UI will update via observers.
        completion(true, nil)
    }

    // MARK: - Helpers

    private func resolvedDurationSeconds() -> TimeInterval {
        let cal = Calendar.current
        let startComponents = cal.dateComponents([.hour, .minute], from: startTime)
        let endComponents   = cal.dateComponents([.hour, .minute],   from: endTime)
        guard let sHour = startComponents.hour,
              let sMin  = startComponents.minute,
              let eHour = endComponents.hour,
              let eMin  = endComponents.minute
        else { return 0 }

        var end = cal.date(bySettingHour: eHour, minute: eMin, second: 0, of: sleepDate)!
        var start = cal.date(bySettingHour: sHour, minute: sMin, second: 0, of: sleepDate)!
        if start > end { start = cal.date(byAdding: .day, value: -1, to: start)! }
        let interval = end.timeIntervalSince(start)
        return interval > 0 ? interval : (interval + 24 * 3600)
    }

    private func makeError(_ message: String) -> NSError {
        NSError(domain: "AddSleepData", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
