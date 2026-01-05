//
//  ProfileRowCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 27/10/25.
//

import UIKit

final class ProfileRowCell: UITableViewCell {
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none

    }

}
