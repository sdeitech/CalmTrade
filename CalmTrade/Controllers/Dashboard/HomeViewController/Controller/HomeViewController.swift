//
//  HomeViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 28/08/25.
//

import UIKit

class HomeViewController: UIViewController {

    //MARK: Outlets
    @IBOutlet weak var gaugeContainerView: UIView!
    
     var calmScoreGauge: CalmScoreGaugeView!

     override func viewDidLoad() {
         super.viewDidLoad()
         
//         // 1. Create and add the gauge view
//         calmScoreGauge = CalmScoreGaugeView()
//         gaugeContainerView.addSubview(calmScoreGauge)
//         
//         // 2. Set up constraints
//         calmScoreGauge.translatesAutoresizingMaskIntoConstraints = false
//         NSLayoutConstraint.activate([
//             calmScoreGauge.centerXAnchor.constraint(equalTo: gaugeContainerView.centerXAnchor),
//             calmScoreGauge.topAnchor.constraint(equalTo: gaugeContainerView.safeAreaLayoutGuide.topAnchor, constant: 20),
//             calmScoreGauge.widthAnchor.constraint(equalTo: gaugeContainerView.widthAnchor, multiplier: 0.9),
//             calmScoreGauge.heightAnchor.constraint(equalToConstant: 300)
//         ])
//         
//         // 3. Set the initial score
//         calmScoreGauge.setScore(80, animated: false)
//         
//         // Example: Update the score after 3 seconds
//         DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
//             let newScore = Int.random(in: 10...100)
//             self.calmScoreGauge.setScore(newScore, animated: true)
//             self.calmScoreGauge.lastUpdateText = "Last update: Just now"
//         }
     }
 }
