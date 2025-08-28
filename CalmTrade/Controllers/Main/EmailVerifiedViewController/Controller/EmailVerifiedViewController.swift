//
//  EmailVerifiedViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 26/08/25.
//

import UIKit

class EmailVerifiedViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    
    //MARK: Actions
    @IBAction func btnContinueTapped(_ sender: UIButton) {
        let connectVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ConnectViewController") as! ConnectViewController
        self.navigationController?.pushViewController(connectVC, animated: true)
    }

}
