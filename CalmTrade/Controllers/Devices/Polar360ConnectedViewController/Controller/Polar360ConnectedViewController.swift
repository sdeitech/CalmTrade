//
//  Polar360ConnectedViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/09/25.
//


import UIKit

class Polar360ConnectedViewController: UIViewController {
    
    // This closure will be called when the "Continue" button is tapped.
    var continueHandler: (() -> Void)?
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    // MARK: - Actions
    @IBAction func btnContinueTapped(_ sender: UIButton) {
        continueHandler?()
    }
}
