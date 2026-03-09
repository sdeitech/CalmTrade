//
//  NightlyRechargeBarsView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 09/03/26.
//


import UIKit

final class NightlyRechargeBarsView: UIView {

    private var bars: [UIView] = []
    private let barCount = 22

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        for _ in 0..<barCount {

            let bar = UIView()
            bar.backgroundColor = UIColor.systemTeal
            bar.layer.cornerRadius = 3
            bar.translatesAutoresizingMaskIntoConstraints = false

            bars.append(bar)
            stack.addArrangedSubview(bar)

            bar.heightAnchor.constraint(equalToConstant: 20).isActive = true
        }
    }

    func updateBars(level: CGFloat) {

        for bar in bars {

            let random = CGFloat.random(in: 0.6...1.3)
            let height = 40 * level * random

            UIView.animate(withDuration: 0.4) {
                bar.transform = CGAffineTransform(scaleX: 1, y: height/40)
            }
        }
    }
}