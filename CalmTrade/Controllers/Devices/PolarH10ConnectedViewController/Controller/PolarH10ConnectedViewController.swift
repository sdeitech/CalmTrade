//
//  PolarH10ConnectedViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/09/25.
//


import UIKit

class PolarH10ConnectedViewController: UIViewController {
    
    // This closure will be called when the "Continue" button is tapped.
    var continueHandler: (() -> Void)?
    
    // MARK: - Outlets
    @IBOutlet weak var animationView: UIImageView!
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load the GIF using the helper
//        animationView.loadGifi(name: "polar-h10-connected-gif", repeatCount: 0)
    }
    
    // MARK: - Actions
    @IBAction func btnContinueTapped(_ sender: UIButton) {
        continueHandler?()
    }
}
