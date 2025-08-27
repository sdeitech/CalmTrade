//
//  ConnectViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 27/08/25.
//

import UIKit

class ConnectViewController: BaseViewController {

    lazy var viewModel: ConnectViewModel = {
        let obj = ConnectViewModel()
        self.baseVwModel = obj
        return obj
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewModelBindings()
    }
    
    private func setupViewModelBindings() {
        viewModel.onAuthorizationComplete = { [weak self] success, errorMessage in
            if success {
                // --- SUCCESS ---
                print("Successfully connected to HealthKit!")
                // You can now show the "You're Connected" pop-up.
                self?.showConnectedPopup()
            } else {
                // --- FAILURE ---
                // Show an alert with the error message.
                self?.showAlert(message: errorMessage ?? "Failed to connect.")
            }
        }
    }
    
    private func showConnectedPopup() {
        let appleConnectedVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "AppleConnectedViewController") as! AppleConnectedViewController
        appleConnectedVC.modalPresentationStyle = .overFullScreen
        appleConnectedVC.modalTransitionStyle = .crossDissolve
        present(appleConnectedVC, animated: true)
//        navigationController?.pushViewController(appleConnectedVC, transitionType: .reveal, duration: 0.03)
    }

    @IBAction func btnConnectAppleTapped(_ sender: UIButton) {
        viewModel.connectToHealthKit()
    }
}





