//
//  BiometricsViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 02/09/25.
//


import Foundation
import HealthKit

class BiometricsViewModel {
    
    // MARK: - Properties
    private let healthKitManager = HealthKitManager.shared
    private let calmScoreCalculator = CalmScoreCalculator()
    
    private var biometricData = BiometricData()
    
    // MARK: - Binding
    /// This closure is called whenever the data is updated, so the ViewController can refresh its UI.
    var onDataUpdated: ((BiometricData) -> Void)?
    
    // MARK: - Public Methods
    
    /// The main entry point to start fetching all data.
    func fetchAllBiometrics() {
        healthKitManager.requestAuthorization { [weak self] success, error in
            guard success, error == nil else {
                // Handle error state in UI if needed
                print("HealthKit Authorization failed.")
                return
            }
            self?.startFetchingData()
        }
    }
    
    // MARK: - Private Fetching Logic
    
    private func startFetchingData() {
        let group = DispatchGroup()
        
        group.enter()
        healthKitManager.fetchLatestHeartRate { [weak self] sample in
            if let sample = sample {
                let bpm = sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
                self?.biometricData.heartRateLatest = "\(Int(bpm))"
                // For now, Average is the same as Latest. A real implementation would query more data.
                self?.biometricData.heartRateAverage = "\(Int(bpm))"
            }
            group.leave()
        }
        
        group.enter()
        healthKitManager.fetchLatestHRV { [weak self] sample in
            if let sample = sample {
                let ms = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                self?.biometricData.hrvLatest = "\(Int(ms))"
                self?.biometricData.hrvAverage = "\(Int(ms))"
                self?.biometricData.hrvTimestamp = self?.formatTimestamp(sample.endDate) ?? ""
            }
            group.leave()
        }
        
        group.enter()
        healthKitManager.fetchLatestRestingHeartRate { [weak self] sample in
            if let sample = sample {
                let bpm = sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
                self?.biometricData.restingHeartRateLatest = "\(Int(bpm))"
                self?.biometricData.restingHeartRateAverage = "\(Int(bpm))"
                self?.biometricData.restingHeartRateTimestamp = self?.formatTimestamp(sample.endDate) ?? ""
            }
            group.leave()
        }
        
        group.enter()
        healthKitManager.fetchTodaysStepCount { [weak self] steps in
            if let steps = steps {
                self?.biometricData.stepsToday = "\(Int(steps))"
                self?.biometricData.stepsDate = self?.formatDate(Date()) ?? ""
            }
            group.leave()
        }
        
        group.enter()
        healthKitManager.fetchSleepAnalysis { [weak self] totalSleep in
            if let totalSleep = totalSleep {
                self?.biometricData.sleepTotal = self?.formatTimeInterval(totalSleep) ?? "--"
                self?.biometricData.sleepDate = self?.formatDate(Date()) ?? ""
            }
            group.leave()
        }
        
        // When all asynchronous fetches are complete, update the UI.
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.biometricData.lastUpdateTimestamp = "Last update \(self.formatFullTimestamp(Date()))"
            
            // TODO: Calculate real CalmScore when more data is available
            self.biometricData.calmScore = "80"
            
            self.onDataUpdated?(self.biometricData)
        }
    }
    
    // MARK: - Formatting Helpers
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss a"
        return formatter.string(from: date)
    }
    
    private func formatFullTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy HH:mm:ss a"
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM" // e.g., "28 Aug"
        return formatter.string(from: date)
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        return "\(hours)hr \(minutes)min"
    }
}
