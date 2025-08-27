//
//  HealthKitService.swift
//  CalmTrade
//
//  Created by Anas Parekh on 27/08/25.
//


import Foundation
import HealthKit

/// A centralized service to manage all interactions with Apple's HealthKit.
class HealthKitService {
    
    // MARK: - Properties
    
    private let healthStore = HKHealthStore()
    
    // MARK: - Authorization
    
    /// Requests permission from the user to read and write health data.
    /// - Parameter completion: A closure that returns true if authorization was successful, or false with an error on failure.
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        // 1. Check if HealthKit is available on this device.
        guard HKHealthStore.isHealthDataAvailable() else {
            let error = NSError(domain: "com.calmtrade.healthkit", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device."])
            completion(false, error)
            return
        }
        
        // 2. Define the data types we want to read from HealthKit.
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
              let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            
            let error = NSError(domain: "com.calmtrade.healthkit", code: 2, userInfo: [NSLocalizedDescriptionKey: "One or more HealthKit data types are unavailable."])
            completion(false, error)
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            heartRateType,
            restingHeartRateType,
            hrvType,
            stepsType,
            sleepType
        ]
        
        // 3. Define the data types we want to write to HealthKit.
        let typesToWrite: Set<HKSampleType> = [
            sleepType
        ]
        
        // 4. Request authorization from the user.
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            // The completion handler is called on a background thread, so we dispatch to the main thread.
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error)
                    return
                }
                
                if success {
                    print("HealthKit authorization successful.")
                    completion(true, nil)
                } else {
                    print("HealthKit authorization was denied by the user.")
                    let authError = NSError(domain: "com.calmtrade.healthkit", code: 3, userInfo: [NSLocalizedDescriptionKey: "Authorization was denied."])
                    completion(false, authError)
                }
            }
        }
    }
    
    
}
