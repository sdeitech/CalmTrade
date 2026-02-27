//
//  BreathingViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 01/09/25.
//  UPDATED: Uses HealthKitService (read-only) and observes Mindful Sessions.
//

import Foundation
import HealthKit

final class BreathingViewModel {

    // MARK: - Properties
    private let hk = HealthKitService.shared
    private var mindfulObserver: HKObserverQuery?
    private let anchorKey = "ct.hk.anchor.mindfulSession"

    // MARK: - Output Closures (for binding to the View)
    var showUserInstruction: (() -> Void)?
    var navigateToEmotionalTags: (() -> Void)?
    var navigateToDashboard: (() -> Void)?
    var showError: ((String, String) -> Void)? // (title, message)

    // MARK: - Input Methods (called by the View)

    /// Called when the "Start Session" button is tapped.
    func startSessionTapped() {
        requestMindfulAuthorization { [weak self] ok, err in
            guard let self else { return }
            if let err = err {
                DispatchQueue.main.async {
                    self.showError?("HealthKit Error", "Could not get permission: \(err.localizedDescription)")
                }
                return
            }
            guard ok else {
                DispatchQueue.main.async {
                    self.showError?("Permission Denied", "Please enable Health access in Settings to use this feature.")
                }
                return
            }

            // Begin observing new Mindful Session samples (read-only)
            self.startObservingMindfulnessSessions {
                // Called when a new session is detected
                DispatchQueue.main.async {
                    self.navigateToEmotionalTags?()
                }
            }

            // Ask user to start the breathing/mindfulness session on the watch
            DispatchQueue.main.async {
                self.showUserInstruction?()
            }
        }
    }

    /// Called when the "Skip" button is tapped.
    func skipTapped() {
        DispatchQueue.main.async {
            self.navigateToDashboard?()
        }
    }

    /// Called when the view is about to disappear to clean up resources.
    func viewWillDisappear() {
        stopObserving()
    }
}

// MARK: - HealthKit (read-only) helpers
private extension BreathingViewModel {

    var mindfulType: HKCategoryType {
        HKCategoryType.categoryType(forIdentifier: .mindfulSession)!
    }

    func requestMindfulAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "HealthKit", code: 1,
                                      userInfo: [NSLocalizedDescriptionKey: "Health data unavailable"]))
            return
        }
        // We only request READ for mindful sessions (no writes anywhere).
        hk.healthStore.requestAuthorization(toShare: [], read: [mindfulType]) { ok, err in
            completion(ok, err)
        }
    }

    func startObservingMindfulnessSessions(onNewSession: @escaping () -> Void) {
        // Stop any existing observer first
        stopObserving()

        // Enable background delivery (safe even if not strictly needed for this screen)
        hk.healthStore.enableBackgroundDelivery(for: mindfulType, frequency: .immediate) { _, _ in }

        // Observe changes
        let q = HKObserverQuery(sampleType: mindfulType, predicate: nil) { [weak self] _, completion, error in
            defer { completion() }
            guard let self, error == nil else { return }
            self.fetchMindfulDeltas { hasNew in
                if hasNew { onNewSession() }
            }
        }
        hk.healthStore.execute(q)
        mindfulObserver = q

        // Kick an initial fetch so we react if something already exists
        fetchMindfulDeltas { _ in }
    }

    func stopObserving() {
        if let q = mindfulObserver {
            hk.healthStore.stop(q)
            mindfulObserver = nil
        }
    }

    // Anchored fetch to know if there are new samples since last check
    func fetchMindfulDeltas(completion: @escaping (Bool) -> Void) {
        let prevAnchor = loadAnchor()
        let anchored = HKAnchoredObjectQuery(type: mindfulType,
                                             predicate: nil,
                                             anchor: prevAnchor,
                                             limit: HKObjectQueryNoLimit) { [weak self] _, new, _, newAnchor, error in
            guard let self, error == nil else { completion(false); return }
            if let a = newAnchor { self.saveAnchor(a) }
            completion(!(new ?? []).isEmpty)
        }
        hk.healthStore.execute(anchored)
    }

    // MARK: Anchor persistence (UserDefaults)
    func loadAnchor() -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: anchorKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }
    func saveAnchor(_ a: HKQueryAnchor) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: a, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: anchorKey)
        }
    }
}
