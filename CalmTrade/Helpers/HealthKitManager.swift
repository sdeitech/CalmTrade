//
//  HealthKitManager.swift
//  CalmTrade
//
//  Created by Anas Parekh on 01/09/25.
//


import Foundation
import HealthKit

/// A singleton class to manage all HealthKit-related operations.
class HealthKitManager {
    
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()
    
    private var observerQuery: HKObserverQuery?
    private let sampleType = HKCategoryTypeIdentifier.mindfulSession
    
    // This flag will help us ignore the initial, automatic callback from the query.
    private var isObserving = false
    
    private var readTypes: Set<HKObjectType> {
        return [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ]
    }
    
    private init() {}
    
    /// Requests user authorization to read and share mindfulness data.
    func requestAuthorizationForBreathingSession(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }
        
        let typesToShare: Set = [sampleType]
        let typesToRead: Set<HKObjectType> = []
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    /// Starts observing for new mindfulness sessions being saved to HealthKit.
    /// - Parameter updateHandler: A closure that is called ONLY when a new session is detected after the initial setup.
    func startObservingMindfulnessSessions(updateHandler: @escaping () -> Void) {
        // If a query is already running, don't start another.
        guard !isObserving else {
            print("Observer is already running.")
            return
        }
        
        let predicate = HKQuery.predicateForWorkouts(with: .mindAndBody)
        
        observerQuery = HKObserverQuery(sampleType: sampleType, predicate: predicate) { [weak self] query, completionHandler, error in
            guard let self = self else { return }
            
            // --- THIS IS THE KEY LOGIC CHANGE ---
            // The first time the handler is called, 'isObserving' is false.
            // We flip the flag and ignore this callback.
            guard self.isObserving else {
                self.isObserving = true
                print("Observer query started. Now waiting for user to start a session.")
                completionHandler()
                return
            }
            
            // Any subsequent call means a real change happened.
            print("Genuine HealthKit update received! A mindfulness session was started.")
            
            self.stopObserving() // Stop listening to prevent multiple navigations.
            
            DispatchQueue.main.async {
                updateHandler() // This will now trigger the navigation at the correct time.
            }
            
            // You must always call the completion handler.
            completionHandler()
        }
        
        healthStore.execute(observerQuery!)
        
        healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { _,_ in }
    }
    
    /// Stops the active HealthKit observer query and resets its state.
    func stopObserving() {
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }
        isObserving = false // Reset the flag so the next observation starts fresh.
        print("Stopped observing HealthKit changes.")
    }
    
    /// Requests user authorization for all necessary biometrics data types.
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil) // Or a custom error for device not supported
            return
        }
        
        // We only need to read data for this screen.
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    // MARK: - Specific Data Fetching Functions
    
    func fetchLatestHeartRate(completion: @escaping (HKQuantitySample?) -> Void) {
        fetchMostRecentSample(for: .quantityType(forIdentifier: .heartRate)!, completion: completion)
    }
    
    func fetchLatestHRV(completion: @escaping (HKQuantitySample?) -> Void) {
        fetchMostRecentSample(for: .quantityType(forIdentifier: .heartRateVariabilitySDNN)!, completion: completion)
    }
    
    func fetchLatestRestingHeartRate(completion: @escaping (HKQuantitySample?) -> Void) {
        fetchMostRecentSample(for: .quantityType(forIdentifier: .restingHeartRate)!, completion: completion)
    }
    
    func fetchTodaysStepCount(completion: @escaping (Double?) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let totalSteps = result?.sumQuantity()?.doubleValue(for: .count())
            DispatchQueue.main.async {
                completion(totalSteps)
            }
        }
        healthStore.execute(query)
    }
    
    func fetchSleepAnalysis(completion: @escaping (TimeInterval?) -> Void) {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        // Predicate to get sleep data from the last 24 hours
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .day, value: -1, to: Date()), end: Date(), options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let totalSleep = samples?
                .compactMap { $0 as? HKCategorySample }
                .filter { $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue } // We only count time "in bed and asleep"
                .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            
            DispatchQueue.main.async {
                completion(totalSleep)
            }
        }
        healthStore.execute(query)
    }
    
    // A generic helper function to get the most recent sample of a given type
    func fetchMostRecentSample<T: HKSample>(for sampleType: HKSampleType, completion: @escaping (T?) -> Void) {
        let mostRecentPredicate = HKQuery.predicateForSamples(withStart: .distantPast, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: sampleType, predicate: mostRecentPredicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            DispatchQueue.main.async {
                completion(samples?.first as? T)
            }
        }
        healthStore.execute(query)
    }
    
    // MARK: - New Statistics Query Function
    
    /// Fetches and aggregates statistics for a given quantity type over a specified time range.
    /// This is the ideal method for gathering data for charts.
    /// - Parameters:
    ///   - quantityType: The type of data to fetch (e.g., HRV).
    ///   - predicate: The time range for the query.
    ///   - interval: The time interval to group data by (e.g., per hour, per day).
    ///   - anchorDate: A reference date to align the intervals.
    ///   - completion: A closure that returns the resulting statistics collection.
    func fetchStatisticsCollection(for quantityType: HKQuantityType,
                                   predicate: NSPredicate,
                                   interval: DateComponents,
                                   anchorDate: Date,
                                   completion: @escaping (HKStatisticsCollection?) -> Void) {
        
        let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                quantitySamplePredicate: predicate,
                                                options: .discreteAverage, // We want the average value for each interval
                                                anchorDate: anchorDate,
                                                intervalComponents: interval)
        
        // This handler will be called with the initial results.
        query.initialResultsHandler = { _, results, _ in
            DispatchQueue.main.async {
                completion(results)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchStatisticsCollection(for quantityType: HKQuantityType,
                                       predicate: NSPredicate,
                                       options: HKStatisticsOptions, // Now accepts options (sum, average, etc.)
                                       anchorDate: Date,
                                       interval: DateComponents,
                                   completion: @escaping (HKStatisticsCollection?) -> Void) {
        
        let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                quantitySamplePredicate: predicate,
                                                options: options,
                                                anchorDate: anchorDate,
                                                intervalComponents: interval)
        
        query.initialResultsHandler = { _, results, _ in
            DispatchQueue.main.async {
                completion(results)
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Live Update Observer
        
        /// Sets up background queries that will fire whenever new biometric data is saved to HealthKit.
        /// - Parameter updateHandler: A closure that is called each time a new sample is detected.
        func startObservingBiometrics(updateHandler: @escaping () -> Void) {
            let allTypes = Array(readTypes)
            
            for type in allTypes {
                let query = HKObserverQuery(sampleType: type as! HKSampleType, predicate: nil) { query, completionHandler, error in
                    guard error == nil else {
                        print("Observer query failed for type \(type.identifier) with error: \(error!)")
                        completionHandler()
                        return
                    }
                    
                    print("HealthKit update detected for type: \(type.identifier)")
                    // A new sample was saved. Tell the DeviceManager to fetch the latest data.
                    updateHandler()
                    
                    // You must call the completion handler to re-arm the query.
                    completionHandler()
                }
                healthStore.execute(query)
                
                // Enable background delivery for this type
                healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
                    if success {
                        print("Background delivery enabled for \(type.identifier).")
                    } else if let error = error {
                        print("Failed to enable background delivery for \(type.identifier): \(error.localizedDescription)")
                    }
                }
            }
        }
}

