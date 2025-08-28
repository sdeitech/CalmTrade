//
//  AccountCreatedViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 28/08/25.
//

import UIKit

class AccountCreatedViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    //MARK: Actions
    @IBAction func btnGoToDashboardTapped(_ sender: Any) {
        let tabBarController = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil).instantiateViewController(withIdentifier: "TabbarController") as! TabbarController
        navigationController?.pushViewController(tabBarController, transitionType: .reveal, duration: 0.03)
    }

}
