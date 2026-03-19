//
//  BaselineIndicatorView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 09/03/26.
//


import UIKit

final class BaselineIndicatorView: UIView {

    private let trackView = UIView()
    private let baselineLine = UIView()
    private let valueBubble = UILabel()

    private var bubbleCenterConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {

        trackView.backgroundColor = UIColor(white: 0.25, alpha: 1)
        trackView.layer.cornerRadius = 15
        trackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(trackView)

        NSLayoutConstraint.activate([
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            trackView.heightAnchor.constraint(equalToConstant: 36)
        ])

        baselineLine.backgroundColor = .white
        baselineLine.translatesAutoresizingMaskIntoConstraints = false
        trackView.addSubview(baselineLine)

        NSLayoutConstraint.activate([
            baselineLine.widthAnchor.constraint(equalToConstant: 2),
            baselineLine.centerXAnchor.constraint(equalTo: trackView.centerXAnchor),
            baselineLine.centerYAnchor.constraint(equalTo: trackView.centerYAnchor),
            baselineLine.heightAnchor.constraint(equalToConstant: 50)
        ])

        baselineLine.layer.borderWidth = 1
        baselineLine.layer.borderColor = UIColor.white.cgColor
        baselineLine.backgroundColor = .clear

        valueBubble.backgroundColor = UIColor.systemTeal
        valueBubble.textAlignment = .center
        valueBubble.textColor = .white
        valueBubble.font = .systemFont(ofSize: 16, weight: .medium)
        valueBubble.layer.cornerRadius = 15
        valueBubble.clipsToBounds = true
        valueBubble.translatesAutoresizingMaskIntoConstraints = false

        trackView.addSubview(valueBubble)

        bubbleCenterConstraint =
            valueBubble.centerXAnchor.constraint(equalTo: trackView.centerXAnchor)

        NSLayoutConstraint.activate([
            bubbleCenterConstraint,
            valueBubble.centerYAnchor.constraint(equalTo: trackView.centerYAnchor),
            valueBubble.heightAnchor.constraint(equalToConstant: 30),
            valueBubble.widthAnchor.constraint(equalToConstant: 63)
        ])
    }

    func configure(valueText: String, offsetRatio: CGFloat) {

        valueBubble.text = valueText

        let maxOffset = trackView.bounds.width * 0.35
        let clampedRatio = min(1, max(-1, offsetRatio))
        let offset = maxOffset * clampedRatio

        bubbleCenterConstraint.constant = offset

        UIView.animate(withDuration: 0.35) {
            self.layoutIfNeeded()
        }
    }
}
