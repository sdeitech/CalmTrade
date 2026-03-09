//
//  SleepScoreCollectionCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/03/26.
//


import UIKit

final class SleepScoreCollectionCell: UICollectionViewCell {
    
    static let identifier = "SleepScoreCollectionCell"
    
    let radialView = SleepScoreRadialView()
    let scoreLabel = UILabel()
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
        
        radialView.translatesAutoresizingMaskIntoConstraints = false
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        scoreLabel.font = .boldSystemFont(ofSize: 24)
        scoreLabel.textColor = .white
        scoreLabel.textAlignment = .center
        
        dateLabel.font = .systemFont(ofSize: 13, weight: .medium)
        dateLabel.textColor = .systemTeal
        dateLabel.textAlignment = .center
        
        contentView.addSubview(radialView)
        contentView.addSubview(scoreLabel)
        contentView.addSubview(dateLabel)
        
        NSLayoutConstraint.activate([
            radialView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            radialView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            radialView.widthAnchor.constraint(equalToConstant: 80),
            radialView.heightAnchor.constraint(equalToConstant: 80),
            
            scoreLabel.topAnchor.constraint(equalTo: radialView.bottomAnchor, constant: 15),
            scoreLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            dateLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 5),
            dateLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
//            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 14)
        ])
    }
    
    func configure(model: SleepScoreDayModel) {
        radialView.configure(score: model.score)
        scoreLabel.text = "\(model.score)/100"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM yyyy"
        dateLabel.text = formatter.string(from: model.date)
    }
}
