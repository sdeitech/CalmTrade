//
//  CurrentPlanFeatureCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 15/12/25.
//


//
//  CurrentPlanFeatureCell.swift
//  CalmTrade
//

import UIKit

final class CurrentPlanFeatureCell: UITableViewCell {

    @IBOutlet weak var lblFeature: UILabel!
    @IBOutlet weak var imgIncluded: UIImageView!

    func configure(_ feature: SubscriptionFeature) {
        lblFeature.text = feature.name
        imgIncluded.image = UIImage(named: feature.included ? "tick" : "cross")
    }
}
