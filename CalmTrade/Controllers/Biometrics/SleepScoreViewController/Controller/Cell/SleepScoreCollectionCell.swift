//
//  SleepScoreCollectionCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/03/26.
//


import UIKit

final class SleepScoreCollectionCell: UICollectionViewCell {
    
    static let identifier = "SleepScoreCollectionCell"
    
    let scoreContainerView = UIView()
    let dateLabel = UILabel()
    
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
        
        scoreContainerView.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreContainerView.backgroundColor = .clear
        
        dateLabel.font = .systemFont(ofSize: 13, weight: .medium)
        dateLabel.textColor = .systemTeal
        dateLabel.textAlignment = .center
        
        contentView.addSubview(scoreContainerView)
        contentView.addSubview(dateLabel)
        
        NSLayoutConstraint.activate([
            scoreContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            scoreContainerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            scoreContainerView.widthAnchor.constraint(equalToConstant: 110),
            scoreContainerView.heightAnchor.constraint(equalTo: scoreContainerView.widthAnchor),
            
            dateLabel.topAnchor.constraint(equalTo: scoreContainerView.bottomAnchor, constant: 14),
            dateLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
//            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 14)
        ])
    }
    
    func configure(model: SleepScoreDayModel) {
        SleepScoreViewModel.makeSleepScoreRing(
            in: scoreContainerView,
            score: model.score,
            segmentProgresses: [model.amount, model.solidity, model.regeneration],
            centerFontSize: 24
        )
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM yyyy"
        dateLabel.text = formatter.string(from: model.date)
    }
}
