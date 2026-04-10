 //
//  SleepScoreMetricBarView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/03/26.
//


import UIKit

final class SleepScoreMetricBarView: UIView {
    
    private let titleLabel = UILabel()
    private let backgroundBar = UIView()
    private let fillBar = UIView()
    private var heightConstraint: NSLayoutConstraint!
    
    private let maxHeight: CGFloat = 100
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .clear
        
        backgroundBar.backgroundColor = UIColor.darkGray
        backgroundBar.layer.cornerRadius = 6
        backgroundBar.translatesAutoresizingMaskIntoConstraints = false
        
        fillBar.layer.cornerRadius = 6
        fillBar.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        addSubview(backgroundBar)
        backgroundBar.addSubview(fillBar)
        addSubview(titleLabel)
        
        backgroundBar.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -8).isActive = true
        
        NSLayoutConstraint.activate([
            backgroundBar.centerXAnchor.constraint(equalTo: centerXAnchor),
            backgroundBar.widthAnchor.constraint(equalToConstant: 12),
            backgroundBar.heightAnchor.constraint(equalToConstant: maxHeight),
            
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
        
        fillBar.bottomAnchor.constraint(equalTo: backgroundBar.bottomAnchor).isActive = true
        fillBar.leadingAnchor.constraint(equalTo: backgroundBar.leadingAnchor).isActive = true
        fillBar.trailingAnchor.constraint(equalTo: backgroundBar.trailingAnchor).isActive = true
        
        heightConstraint = fillBar.heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.isActive = true
    }
    
    func configure(title: String, value: CGFloat, color: UIColor) {
        titleLabel.text = title
        fillBar.backgroundColor = color
        heightConstraint.constant = maxHeight * value
        
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
    }
}
