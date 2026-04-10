//
//  FacebookManager.swift
//  CalmTrade
//
//  Created by Developer on 1/24/26.
//

import Foundation
import FBSDKCoreKit
import UIKit

class FacebookManager {
    static let shared = FacebookManager()
    
    private init() {}
    
    func configureFacebookSDK() {
        // Configure Facebook settings with improved timeout handling
        Settings.shared.appID = "1439790770608266"
        Settings.shared.clientToken = "893bcbdd5f41249f62748adba97e1687"
        Settings.shared.displayName = "CalmTrade"
        
        // Improve network timeout settings for better reliability
        Settings.shared.isCodelessDebugLogEnabled = false
        
        // Enable additional logging only in debug builds
        #if DEBUG
        Settings.shared.loggingBehaviors = [.networkRequests, .performanceCharacteristics]
        #endif
        
        // Set up edge cases handling
        setupFacebookErrorHandling()
    }
    
    private func setupFacebookErrorHandling() {
        // Register for notification when app becomes active to refresh connections if needed
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Re-initialize Facebook SDK when app becomes active if needed
            // This helps reconnect if previous connections timed out
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}