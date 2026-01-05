//
//  PlanRibbonView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 15/12/25.
//

import UIKit
import Foundation

final class PlanRibbonView: UIView {

    private let label: UILabel = {
        let lbl = UILabel()
        lbl.text = "PRO"
        lbl.textColor = .white
        lbl.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        lbl.textAlignment = .center
        return lbl
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = UIColor.clear
        layer.cornerRadius = 6
        clipsToBounds = true

        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant:0),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 8),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])

        // ROTATE the entire ribbon view
        self.transform = CGAffineTransform(rotationAngle: -45 * CGFloat.pi / 180)
    }
}
