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
        color: UIColor,
        onEdit: (() -> Void)?,
        onDelete: (() -> Void)?,
        onAdd: (() -> Void)?
    ) {

        if let emotion {
            viewEmotion.isHidden = false
            btnAdd.isHidden = true

            lblEmotion.text = emotion.name
            viewEmotion.layer.borderColor = color.cgColor

            btnEdit.addAction(UIAction { _ in onEdit?() }, for: .touchUpInside)
            btnDelete.addAction(UIAction { _ in onDelete?() }, for: .touchUpInside)

        } else {
            viewEmotion.isHidden = true
            btnAdd.isHidden = false
            btnAdd.addAction(UIAction { _ in onAdd?() }, for: .touchUpInside)
        }
    }
}
