//
//  FeatureCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 11/12/25.
//


import UIKit

final class FeatureCell: UITableViewCell {

    @IBOutlet weak var lblFeature: UILabel!
    @IBOutlet weak var imgBasic: UIImageView!
    @IBOutlet weak var imgPro: UIImageView!
    @IBOutlet weak var imgElite: UIImageView!

    func configure(feature: String, basic: Bool, pro: Bool, elite: Bool) {
        lblFeature.text = feature
        imgBasic.isHidden = !basic
        imgPro.isHidden = !pro
        imgElite.isHidden = !elite
    }
}
