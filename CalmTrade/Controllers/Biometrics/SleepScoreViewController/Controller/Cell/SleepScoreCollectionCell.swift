//
//  SleepScoreCollectionCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/03/26.
//


import UIKit

final class SleepScoreCollectionCell: UICollectionViewCell {
    
    static let identifier = "SleepScoreCollectionCell"
    
    private let scoreContainerView = UIView()
    private let dateLabel = UILabel()
    private let metricsStack = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        metricsStack.arrangedSubviews.forEach {
            metricsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }
    
    private func setup() {
        contentView.backgroundColor = UIColor("1D1D21")
        contentView.layer.cornerRadius = 16
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.white.withAlphaComponent(0.04).cgColor
        
        scoreContainerView.translatesAutoresizingMaskIntoConstraints = false
        scoreContainerView.backgroundColor = .clear
        
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        dateLabel.textColor = UIColor("39D2DB")
        dateLabel.textAlignment = .left
        dateLabel.numberOfLines = 2
        
        metricsStack.axis = .vertical
        metricsStack.spacing = 6
        metricsStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(scoreContainerView)
        contentView.addSubview(dateLabel)
        contentView.addSubview(metricsStack)
        
        NSLayoutConstraint.activate([
            scoreContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            scoreContainerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            scoreContainerView.widthAnchor.constraint(equalToConstant: 86),
            scoreContainerView.heightAnchor.constraint(equalTo: scoreContainerView.widthAnchor),
            
            dateLabel.topAnchor.constraint(equalTo: scoreContainerView.bottomAnchor, constant: 10),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            
            metricsStack.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 10),
            metricsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            metricsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            metricsStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(model: SleepScoreDayModel) {
        SleepScoreViewModel.makeSleepScoreRing(
            in: scoreContainerView,
            score: model.score,
            segmentProgresses: [model.amount, model.solidity, model.regeneration],
            centerFontSize: 20
        )
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM yyyy"
        dateLabel.text = formatter.string(from: model.date)
        
        addMetricRow(title: "Sleep Amount", value: "\(model.amountScore)")
        addMetricRow(title: "Sleep Solidity", value: "\(model.solidityScore)")
        addMetricRow(title: "Sleep Regeneration", value: "\(model.regenerationScore)")
    }
    
    private func addMetricRow(title: String, value: String) {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        titleLabel.text = title
        titleLabel.numberOfLines = 1
        
        let valueLabel = UILabel()
        valueLabel.font = .systemFont(ofSize: 12, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.text = value
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(valueLabel)
        
        metricsStack.addArrangedSubview(row)
    }
}
