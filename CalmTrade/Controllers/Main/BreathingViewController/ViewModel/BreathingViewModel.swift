//
//  BreathingViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 01/09/25.
//


import Foundation

class BreathingViewModel {
    
    // MARK: - Properties
    private let healthKitManager: HealthKitManager

    // MARK: - Output Closures (for binding to the View)
    var showUserInstruction: (() -> Void)?
    var navigateToEmotionalTags: (() -> Void)?
    var navigateToDashboard: (() -> Void)?
    var showError: ((String, String) -> Void)? // Parameters: (title, message)

    // MARK: - Initializer
    init(healthKitManager: HealthKitManager = .shared) {
        self.healthKitManager = healthKitManager
    }
    
    // MARK: - Input Methods (called by the View)
    
    /// Called when the "Start Session" button is tapped.
    func startSessionTapped() {
        healthKitManager.requestAuthorizationForBreathingSession { [weak self] success, error in
            if let error = error {
                self?.showError?("HealthKit Error", "Could not get permission: \(error.localizedDescription)")
                return
            }
            
            if success {
                // Once permission is granted, start listening for the session.
                self?.healthKitManager.startObservingMindfulnessSessions {
                    // This is the update handler that gets called when a session starts.
                    self?.navigateToEmotionalTags?()
                }
                // Instruct the user to start the session on their watch.
                self?.showUserInstruction?()
            } else {
                self?.showError?("Permission Denied", "Please enable HealthKit access in Settings to use this feature.")
            }
        }
    }
    
    /// Called when the "Skip" button is tapped.
    func skipTapped() {
        navigateToDashboard?()
    }
    
    /// Called when the view is about to disappear to clean up resources.
    func viewWillDisappear() {
        // Stop the observer to prevent unnecessary background processing.
        healthKitManager.stopObserving()
    }
}
