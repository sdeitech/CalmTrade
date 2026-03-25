//
//  SleepScoreBreakdownCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/03/26.
//


import UIKit

final class SleepScoreBreakdownCell: UICollectionViewCell {
    
    static let identifier = "SleepScoreBreakdownCell"

    private let stack = UIStackView()
    private let amountLabel = UILabel()
    private let sleepTimeLabel = UILabel()
    private let solidityLabel = UILabel()
    private let interruptionsLabel = UILabel()
    private let continuityLabel = UILabel()
    private let efficiencyLabel = UILabel()
    private let regenerationLabel = UILabel()
    private let remLabel = UILabel()
    private let deepLabel = UILabel()
    private let coreLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        contentView.backgroundColor = UIColor(white: 0.1, alpha: 1)
        contentView.layer.cornerRadius = 16

        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        [amountLabel, sleepTimeLabel, solidityLabel, interruptionsLabel, continuityLabel, efficiencyLabel, regenerationLabel, remLabel, deepLabel, coreLabel]
            .forEach {
                $0.textColor = .white
                $0.numberOfLines = 1
                $0.font = UIFont.systemFont(ofSize: 12, weight: .medium)
                stack.addArrangedSubview($0)
            }

        amountLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        solidityLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        regenerationLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)

        sleepTimeLabel.textColor = .systemTeal

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func configure(model: SleepScoreDayModel) {
        amountLabel.text = "Sleep Amount: \(model.amountScore)/40"
        sleepTimeLabel.text = "Sleep Time: \(formatMinutes(model.sleepTimeMinutes))"

        solidityLabel.text = "Sleep Solidity: \(model.solidityScore)/30"
        interruptionsLabel.text = "Interruptions: \(model.interruptionsScore)"
        continuityLabel.text = "Continuity: \(model.continuityScore)"
        efficiencyLabel.text = "Sleep Efficiency: \(model.sleepEfficiencyScore)"

        regenerationLabel.text = "Sleep Regeneration: \(model.regenerationScore)/30"
        remLabel.text = "REM Sleep: \(model.remScore)"
        deepLabel.text = "Deep Sleep: \(model.deepScore)"
        coreLabel.text = "Core Sleep: \(model.coreScore)"
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return "\(h)h \(m)m"
    }
}
