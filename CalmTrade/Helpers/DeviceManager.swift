//
//  DeviceManager.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/09/25.
//


import Foundation
import HealthKit

/// Manages the priority of data sources (Polar vs. HealthKit) and provides a unified interface for fetching biometrics.
class DeviceManager {
    
    static let shared = DeviceManager()
    
    enum DeviceSource {
        case polarH10
        case polar360
        case appleHealthKit
    }
    
    // This property will be updated when a Polar device connects/disconnects.
    // For now, it defaults to HealthKit.
    var currentSource: DeviceSource = .appleHealthKit
    
    // This closure will be called with a new CalmScore whenever it's recalculated.
    var onLiveCalmScoreUpdate: ((CalmScoreSession) -> Void)?
    private let calculator = CalmScoreCalculator()
    
    private let healthKitManager = HealthKitManager.shared
    // TODO: Add instances of your Polar manager classes here later.
    
    /// Fetches statistics for a given quantity type, respecting the device priority.
    func fetchStatisticsCollection(for quantityType: HKQuantityType,
                                   predicate: NSPredicate,
                                   options: HKStatisticsOptions,
                                   anchorDate: Date,
                                   interval: DateComponents,
                                   completion: @escaping (HKStatisticsCollection?) -> Void) {
        
        // --- DEVICE PRIORITY LOGIC ---
        switch currentSource {
        case .polarH10, .polar360:
            // TODO: Add logic here to fetch data from the Polar SDK when it's integrated.
            // For now, we fall through to HealthKit.
            print("Polar device is active, but SDK not integrated. Falling back to HealthKit.")
            fallthrough
            
        case .appleHealthKit:
            healthKitManager.fetchStatisticsCollection(for: quantityType,
                                                       predicate: predicate,
                                                       options: options,
                                                       anchorDate: anchorDate,
                                                       interval: interval,
                                                       completion: completion)
        }
    }
    
    /// Fetches the most recent sample, respecting device priority.
    func fetchMostRecentSample<T: HKSample>(for sampleType: HKSampleType, completion: @escaping (T?) -> Void) {
        // --- DEVICE PRIORITY LOGIC ---
        switch currentSource {
        case .polarH10, .polar360:
            // TODO: Add Polar logic here.
            fallthrough
            
        case .appleHealthKit:
            healthKitManager.fetchMostRecentSample(for: sampleType, completion: completion)
        }
    }
    
    /// Converts an SDNN value from HealthKit to an estimated RMSSD value.
    /// As per the spec: RMSSD ≈ 0.75 * SDNN.
    func convertSdnnToRmssd(_ sdnnValue: Double) -> Double {
        return sdnnValue * 0.75
    }
    
    /// Initiates the live update system. Call this from your main ViewModel.
        func startLiveCalmScoreUpdates(for phase: CalmScoreSession.Phase, initialDataHandler: @escaping (CalmScoreBiometricInputs) -> Void) {
            healthKitManager.requestAuthorization { [weak self] success, _ in
                guard success else { return }
                
                // Set up the observer. The update handler will be called by HealthKit
                // every time new biometric data is available.
                self?.healthKitManager.startObservingBiometrics {
                    print("Observer triggered. Recalculating live CalmScore...")
                    self?.recalculateLiveCalmScore(for: phase, emotionInputs: nil, completion: { initialBiometrics in
                        // This is for subsequent updates, no need to call the initial handler again.
                    })
                }
                
                // Also, perform an initial calculation right away and return the baseline biometrics.
                self?.recalculateLiveCalmScore(for: phase, emotionInputs: nil, completion: initialDataHandler)
            }
        }
        
        /// Can be called from a ViewModel to force a recalculation with new emotional context.
        func recalculateLiveCalmScore(with biometrics: CalmScoreBiometricInputs, emotionInputs: EmotionInputs?, for phase: CalmScoreSession.Phase) {
            let newScore = calculator.calculate(from: biometrics, emotionInputs: emotionInputs, phase: phase)
            onLiveCalmScoreUpdate?(newScore)
            print("Recalculated CalmScore with new emotion: \(newScore.calmScore)")
        }
        
        /// Fetches the latest of all required biometrics, calculates a new CalmScore, and broadcasts it.
        private func recalculateLiveCalmScore(for phase: CalmScoreSession.Phase, emotionInputs: EmotionInputs?, completion: @escaping (CalmScoreBiometricInputs) -> Void) {
            let group = DispatchGroup()
            
            var latestHR: Double?
            var latestHRV: Double?
            var latestRHR: Double?
            var latestSleep: Double?
            
            group.enter()
            fetchMostRecentSample(for: HKObjectType.quantityType(forIdentifier: .heartRate)!) { (sample: HKQuantitySample?) in
                latestHR = sample?.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
                group.leave()
            }
            
            group.enter()
            fetchMostRecentSample(for: HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!) { (sample: HKQuantitySample?) in
                if let sdnn = sample?.quantity.doubleValue(for: .secondUnit(with: .milli)) {
                    latestHRV = self.convertSdnnToRmssd(sdnn) // Convert to RMSSD
                }
                group.leave()
            }
            
            group.enter()
            fetchMostRecentSample(for: HKObjectType.quantityType(forIdentifier: .restingHeartRate)!) { (sample: HKQuantitySample?) in
                latestRHR = sample?.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
                group.leave()
            }
            
            group.enter()
            fetchMostRecentSample(for: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!) { (sample: HKCategorySample?) in
                if let sleepSample = sample, sleepSample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                    latestSleep = sleepSample.endDate.timeIntervalSince(sleepSample.startDate) / 3600.0 // Convert to hours
                }
                group.leave()
            }
            
            group.notify(queue: .main) {
                let inputs = CalmScoreBiometricInputs(
                    heartRate: latestHR,
                    hrvInRmssd: latestHRV,
                    restingHeartRate: latestRHR,
                    sleepDurationInHours: latestSleep
                )
                
                // Return the fetched biometrics
                completion(inputs)
                
                let newScore = self.calculator.calculate(from: inputs, emotionInputs: emotionInputs, phase: phase)
                self.onLiveCalmScoreUpdate?(newScore)
                print("New Live CalmScore Calculated: \(newScore.calmScore)")
            }
        }
}
