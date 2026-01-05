//
//  OrderSuccessfullViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 10/12/25.
//

import UIKit

class OrderSuccessfullViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    //MARK: - Actions
    @IBAction func goToDashboardTapped(_ sender: Any) {
        self.navigationController?.pushViewController(UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil).instantiateViewController(withIdentifier: "TabbarController") as! TabbarController, transitionType: .pop(from: .fromLeft))
    }

}
