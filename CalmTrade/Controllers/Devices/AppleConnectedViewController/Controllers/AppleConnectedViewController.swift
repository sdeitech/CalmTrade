//
//  AppleConnectedViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 27/08/25.
//


import UIKit

class AppleConnectedViewController: UIViewController {

    // MARK: - Outlets
    
    // Connect these to your two UIImageViews in the Storyboard
    @IBOutlet weak var waveImageView: UIImageView!
    @IBOutlet weak var heartbeatImageView: UIImageView!
    
    // MARK: - Properties
    var onContinueTapped: (() -> Void)?

    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAnimations()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Start the animations when the view is visible on screen
        waveImageView.startAnimating()
        heartbeatImageView.startAnimating()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop the animations when the view is no longer visible to save memory
        waveImageView.stopAnimating()
        heartbeatImageView.stopAnimating()
    }

    // MARK: - Setup
    
    private func setupAnimations() {
        // 1. Load the "wave" GIF and set it to loop forever (repeatCount: 0)
        waveImageView.loadGifi(name: "wave animation", repeatCount: 0)
        
        // 2. Load the "heartbeat" GIF and set it to loop forever
        heartbeatImageView.loadGifi(name: "heartbeat", repeatCount: 0)
    }
    
    //MARK: - Action
    
    @IBAction func btnContinueTapped(_ sender: Any) {
        onContinueTapped?()
    }
}
