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

            // Check if user is already logged in and navigate accordingly
            self.checkAuthenticationStatus()
        })
    }

    func playGIF(completion: (() -> Void)?) {

        // Load the GIF and get its duration.
        let duration = splashAnimationImageView.loadGifi(name: "splash_animation", repeatCount: 0) - 1.0

        // Start the animation.
        splashAnimationImageView.startAnimating()

        // Schedule the completion handler to run after the animation duration.
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            completion?()
        }
    }

    private func checkAuthenticationStatus() {
        // Check if user has a valid token
        if let token = UserDefaults.standard.string(forKey: "accessToken"), !token.isEmpty {
            self.navigateToMainApp()
        }
        // If no token, stay on splash screen for user to login/signup
    }

    private func navigateToMainApp() {
        DispatchQueue.main.async {
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
               let window = sceneDelegate.window {

                let tab = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil).instantiateViewController(withIdentifier: "TabbarController") as! TabbarController
                tab.navigationController?.navigationBar.isHidden = true
                let nav = UINavigationController(rootViewController: tab)
                nav.navigationBar.isHidden = true

                window.rootViewController = nav
                window.makeKeyAndVisible()
            }
        }
    }

    @IBAction func btnLoginClk(_ sender: UIButton) {
        let loginViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "LoginViewController") as! LoginViewController
        self.navigationController?.pushViewController(loginViewController,transitionType: .fade)
    }

    @IBAction func btnSignUpClk(_ sender: UIButton) {
        let signUpVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SignUpViewController") as! SignUpViewController
        self.navigationController?.pushViewController(signUpVC, transitionType: .fade)
    }
}
