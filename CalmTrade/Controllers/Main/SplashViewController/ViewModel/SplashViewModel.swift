//
//  SplashViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/08/25.
//

import Foundation

class SplashViewModel: BaseViewModel {

    override init() {
        super.init()

        // Set up the redirect closure to handle navigation after authentication
        self.redirectControllerClosure = { [weak self] in
            self?.handleNavigation()
        }
    }

    private func handleNavigation() {
        // This method can be called when authentication is complete
        // Currently, navigation is handled directly in the view controller
    }
}
