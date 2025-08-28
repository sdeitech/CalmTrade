//
//  ConnectViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 27/08/25.
//


import Foundation

class ConnectViewModel: BaseViewModel {
    
    // MARK: - Properties
    
    private let healthKitService = HealthKitService()
    
    /// A closure that is called with the result of the authorization request.
    var onAuthorizationComplete: ((Bool, String?) -> Void)?
    
    // MARK: - Public Methods
    
    /// Initiates the HealthKit authorization process.
    func connectToHealthKit() {
        healthKitService.requestAuthorization { [weak self] success, error in
            if success {
                self?.onAuthorizationComplete?(true, nil)
            } else {
                self?.onAuthorizationComplete?(false, error?.localizedDescription ?? "An unknown error occurred.")
            }
        }
    }
}
