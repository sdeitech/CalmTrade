//
//  SleepScoreRadialView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/03/26.
//


import UIKit

final class SleepScoreRadialView: UIView {
    
    private var layersArray: [CAShapeLayer] = []
    private var currentScore: Int = 0
    
    private let segmentColors: [UIColor] = [
        UIColor.systemTeal,
        UIColor.systemOrange,
        UIColor.systemPurple,
        UIColor.systemGreen,
        UIColor.systemYellow,
        UIColor.systemOrange.withAlphaComponent(0.8)
    ]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        createLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        createLayers()
    }
    
    private func createLayers() {
        for color in segmentColors {
            let layer = CAShapeLayer()
            layer.fillColor = color.cgColor
            self.layer.addSublayer(layer)
            layersArray.append(layer)
        }
    }
    
    func configure(score: Int) {
        currentScore = max(0, min(100, score))
        layoutSegments(score: score)
    }
    
    private func layoutSegments(score: Int) {
        guard bounds.width > 0 else { return }
        
        let centerPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius: CGFloat = min(bounds.width, bounds.height) / 3
        let barWidth: CGFloat = 8
        let minLength: CGFloat = 14
        let maxLength: CGFloat = 26
        
        let normalized = CGFloat(score) / 100.0
        let length = minLength + (maxLength - minLength) * normalized
        
        for (index, shapeLayer) in layersArray.enumerated() {
            
            let angle = CGFloat(index) * (.pi / 3)
            
            let path = UIBezierPath(
                roundedRect: CGRect(
                    x: -barWidth / 2,
                    y: -radius - length,
                    width: barWidth,
                    height: length
                ),
                cornerRadius: barWidth / 2
            )
            
            shapeLayer.path = path.cgPath
            shapeLayer.position = centerPoint
            shapeLayer.setAffineTransform(CGAffineTransform(rotationAngle: angle))
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutSegments(score: currentScore)
    }
}
