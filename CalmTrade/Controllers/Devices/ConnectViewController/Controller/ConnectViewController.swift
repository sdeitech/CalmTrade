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
                DispatchQueue.main.async {
                    self?.showAppleConnectedScreen()
                }
            } else {
                // --- FAILURE ---
                // Show an alert with the error message.
                self?.showAlert(message: errorMessage ?? "Failed to connect.")
            }
        }
    }
    
    func showAppleConnectedScreen() {
        let storyboard = UIStoryboard(name: Constants.Storyboard.Devices, bundle: nil) // Or your storyboard name
        let appleConnectedVC = storyboard.instantiateViewController(withIdentifier: "AppleConnectedViewController") as! AppleConnectedViewController

        // Set the callback closure
        appleConnectedVC.onContinueTapped = { [weak self] in
            // This code will run when the "Continue" button is tapped inside AppleConnectedViewController.
            
            // 1. First, dismiss the presented view controller.
            self?.dismiss(animated: true) {
                // 2. Then, push the next view controller.
                let breathingVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "BreathingViewController") as! BreathingViewController
                self?.navigationController?.pushViewController(breathingVC, animated: true)
            }
        }

        // Present the view controller (e.g., modally)
        self.present(appleConnectedVC, animated: true)
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
    
    @IBAction func btnSkipTapped(_ sender: UIButton) {
        let breathingVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "BreathingViewController") as! BreathingViewController
        navigationController?.pushViewController(breathingVC, transitionType: .fade, duration: 0.03)
    }
    
    @IBAction func btnConnectPolarTapped(_ sender: UIButton) {
        let polarVC = UIStoryboard(name: Constants.Storyboard.Devices, bundle: nil).instantiateViewController(withIdentifier: "PolarConnectionViewController") as! PolarConnectionViewController
        polarVC.isFromStart = true
        navigationController?.pushViewController(polarVC, transitionType: .fade, duration: 0.03)
    }
}
