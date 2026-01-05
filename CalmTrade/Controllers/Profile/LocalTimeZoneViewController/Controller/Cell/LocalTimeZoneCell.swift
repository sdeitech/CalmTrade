//
//  LocalTimeZoneCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 30/10/25.
//

import UIKit

final class LocalTimeZoneCell: UITableViewCell {

    @IBOutlet private weak var label: UILabel!
    @IBOutlet private weak var checkmarkImageView: UIImageView!

    func configure(with zone: LocalTimeZoneModel, selected: Bool) {
        label.text = zone.labelNow
        checkmarkImageView.isHidden = !selected
    }
}
