//
//  SplashViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/08/25.
//

import UIKit

class SplashViewController: BaseViewController {
    
    @IBOutlet weak var splashAnimationImageView: UIImageView!
    
    lazy var viewModel: SplashViewModel = {
            let obj = SplashViewModel()
            self.baseVwModel = obj
            return obj
        }()
    
    
    // MARK: // Apple Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.playGIF(completion: {
            self.splashAnimationImageView.stopAnimating()
            self.splashAnimationImageView.isHidden = true
        })
    }
    
    func playGIF(completion: (() -> Void)?) {

        // Load the GIF and get its duration.
        let duration = splashAnimationImageView.loadGif(name: "splash_animation", repeatCount: 0) - 1.0
        
        // Start the animation.
        splashAnimationImageView.startAnimating()
        
        // Schedule the completion handler to run after the animation duration.
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            completion?()
        }
    }

    @IBAction func btnLoginClk(_ sender: UIButton) {
        let loginViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "LoginViewController") as! LoginViewController
        self.navigationController?.pushViewController(loginViewController,transitionType: .fade)
    }
    
    @IBAction func btnSignUpClk(_ sender: UIButton) {
        let signUpVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "EmotionalTagsViewController") as! EmotionalTagsViewController
        self.navigationController?.pushViewController(signUpVC, transitionType: .fade)
    }
}
