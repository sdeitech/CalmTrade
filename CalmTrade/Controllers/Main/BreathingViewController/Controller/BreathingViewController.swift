//
//  BreathingViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 28/08/25.
//

import UIKit

class BreathingViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    //MARK: Actions
    @IBAction func btnStartSessionTapped(_ sender: UIButton) {
        let emotionalTagsVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "EmotionalTagsViewController") as! EmotionalTagsViewController
        navigationController?.pushViewController(emotionalTagsVC, transitionType: .fade, duration: 0.03)
    }

    @IBAction func btnSkipTapped(_ sender: UIButton) {
        let dashboardVC = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil).instantiateViewController(withIdentifier: "TabbarController") as! TabbarController
        navigationController?.pushViewController(dashboardVC, transitionType: .fade, duration: 0.03)
    }
}
