//
//  ManageEmotionCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 21/01/26.
//

import UIKit

final class ManageEmotionCell: UITableViewCell {

    @IBOutlet weak var viewEmotion: UIView!
    @IBOutlet weak var lblEmotion: UILabel!
    @IBOutlet weak var btnEdit: UIButton!
    @IBOutlet weak var btnDelete: UIButton!
    @IBOutlet weak var btnAdd: UIButton!

    func configure(
        emotion: EmotionTagModel?,
        color: UIColor
    ) {

        if let emotion {
            viewEmotion.isHidden = false
            btnAdd.isHidden = true

            lblEmotion.text = emotion.name
            viewEmotion.layer.borderColor = color.cgColor

        } else {
            viewEmotion.isHidden = true
            btnAdd.isHidden = false
        }
    }
}
