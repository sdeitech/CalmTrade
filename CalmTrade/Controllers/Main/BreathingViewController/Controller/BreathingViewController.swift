//
//  BreathingViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 28/08/25.
//

import UIKit

class BreathingViewController: UIViewController {
    
    // MARK: - Properties
    private lazy var viewModel = BreathingViewModel()

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.viewWillDisappear()
    }
    
    // MARK: - Bindings
    
    /// Connects the ViewModel's outputs to the View's UI updates.
    private func setupBindings() {
        
        // When the ViewModel needs to show the user instruction...
        viewModel.showUserInstruction = { [weak self] in
            DispatchQueue.main.async {
                self?.presentUserInstructionAlert()
            }
        }
        
        // When the ViewModel determines we should navigate to the next screen...
        viewModel.navigateToEmotionalTags = { [weak self] in
            DispatchQueue.main.async {
                // Make sure we don't push the same view controller twice
                guard self?.navigationController?.topViewController is Self else { return }

                let emotionalTagsVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "EmotionalTagsViewController") as! EmotionalTagsViewController
                self?.navigationController?.pushViewController(emotionalTagsVC, transitionType: .fade, duration: 0.03)
            }
        }
        
        // When the ViewModel determines we should skip to the dashboard...
        viewModel.navigateToDashboard = { [weak self] in
            DispatchQueue.main.async {
//            let dashboardVC = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil).instantiateViewController(withIdentifier: "TabbarController") as! TabbarController
//            self?.navigationController?.pushViewController(dashboardVC, transitionType: .fade, duration: 0.03)
                let emotionalTagsVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "EmotionalTagsViewController") as! EmotionalTagsViewController
                self?.navigationController?.pushViewController(emotionalTagsVC, transitionType: .fade, duration: 0.03)
            }
        }
        
        // When the ViewModel encounters an error...
        viewModel.showError = { [weak self] title, message in
            DispatchQueue.main.async {
                // You can create a more sophisticated error alert here.
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }
    
    // MARK: - UI Actions
    
    @IBAction func btnStartSessionTapped(_ sender: UIButton) {
        viewModel.startSessionTapped()
    }

    @IBAction func btnSkipTapped(_ sender: UIButton) {
        viewModel.skipTapped()
    }
    
    // MARK: - Helper Methods
    
    private func presentUserInstructionAlert() {
        let alert = UIAlertController(title: "Start on Your Watch",
                                      message: "Please open the Mindfulness app on your Apple Watch and start a breathe session.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
}
