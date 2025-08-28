//
//  EmotionTagCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 28/08/25.
//

import UIKit

class EmotionTagCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var mainView: UIView!
    @IBOutlet weak var btnSelect: UIButton!
    
    static let reuseIdentifier = "EmotionTagCell"
    private let animatedBorderLayer = CAShapeLayer()
    private var selectionColor: UIColor = .green
    
    // **NEW**: A property to keep track of the selection state
    private var isTagSelected: Bool = false

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        mainView.layer.cornerRadius = mainView.bounds.height / 2
        
        // Always update layer frame & path on layout
        animatedBorderLayer.frame = mainView.bounds
        animatedBorderLayer.path = UIBezierPath(
            roundedRect: mainView.bounds,
            cornerRadius: mainView.bounds.height / 2
        ).cgPath
        
        // If selected, reapply the animation every time layout updates
        if isTagSelected {
            addMovingBorder()
        }
    }

    
    func configure(with title: String, color: UIColor) {
        titleLabel.text = title
        self.selectionColor = color
        
        // Ensure layout is recalculated before animation
        setNeedsLayout()
        layoutIfNeeded()
    }

    
//    func updateSelection(isSelected: Bool) {
//        self.isTagSelected = isSelected
//        
//        if isSelected {
////            mainView.backgroundColor = selectionColor.withAlphaComponent(0.15)
//            titleLabel.textColor = .white
//            mainView.layer.borderColor = UIColor.clear.cgColor
//        } else {
//            mainView.backgroundColor = .clear
//            titleLabel.textColor = .lightGray
//            mainView.borderColor = .init("313131")
//            removeMovingBorder()
//        }
//        
//        // 🔑 Force layout refresh so border uses the latest size
//        setNeedsLayout()
//        layoutIfNeeded()
//    }
    
    func updateSelection(isSelected: Bool) {
        self.isTagSelected = isSelected
        
        if isSelected {
            titleLabel.textColor = .white
            
            // Remove any plain border
            mainView.layer.borderColor = UIColor.clear.cgColor
            
            // Apply gradient border
            applyGradientBorder()
            
            // Apply shadow
            mainView.layer.shadowColor = selectionColor.cgColor
            mainView.layer.shadowOpacity = 1
            mainView.layer.shadowOffset = .zero
            mainView.layer.shadowRadius = 4.8 // matches blur
        } else {
            mainView.backgroundColor = .clear
            titleLabel.textColor = .lightGray
            mainView.layer.sublayers?.removeAll(where: { $0.name == "gradientBorder" })
            
            // Reset shadow
            mainView.layer.shadowOpacity = 0
            mainView.layer.borderWidth = 1
            mainView.borderColor = UIColor.init("313131")
        }
        
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func applyGradientBorder() {
        // Remove old if exists
        mainView.layer.sublayers?.removeAll(where: { $0.name == "gradientBorder" })
        
        let gradient = CAGradientLayer()
        gradient.name = "gradientBorder"
        gradient.frame = mainView.bounds
        gradient.colors = [
            selectionColor.cgColor,
            UIColor.white.withAlphaComponent(0).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        
        let shape = CAShapeLayer()
        shape.lineWidth = 2
        shape.path = UIBezierPath(roundedRect: mainView.bounds, cornerRadius: mainView.bounds.height / 2).cgPath
        shape.strokeColor = UIColor.black.cgColor
        shape.fillColor = UIColor.clear.cgColor
        gradient.mask = shape
        
        mainView.layer.addSublayer(gradient)
    }



    
    private func setupUI() {
        mainView.layer.borderWidth = 1.0
        animatedBorderLayer.lineWidth = 5.0
        animatedBorderLayer.fillColor = UIColor.clear.cgColor
        mainView.layer.addSublayer(animatedBorderLayer)
        updateSelection(isSelected: false)
    }
    
    // MARK: - Animation
    
    private func addMovingBorder() {
        // Remove any existing animation before adding a new one.
        animatedBorderLayer.removeAllAnimations()
        
        animatedBorderLayer.strokeColor = selectionColor.cgColor
        
        let strokeEndAnimation = CABasicAnimation(keyPath: "strokeEnd")
        strokeEndAnimation.fromValue = 0
        strokeEndAnimation.toValue = 1
        strokeEndAnimation.duration = 1.0
        strokeEndAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let strokeStartAnimation = CABasicAnimation(keyPath: "strokeStart")
        strokeStartAnimation.fromValue = 0
        strokeStartAnimation.toValue = 1
        strokeStartAnimation.duration = 1.0
        strokeStartAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        strokeStartAnimation.beginTime = 0.2

        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [strokeEndAnimation, strokeStartAnimation]
        animationGroup.duration = 1.0
        animationGroup.repeatCount = .infinity
        animationGroup.isRemovedOnCompletion = false
        
        animatedBorderLayer.add(animationGroup, forKey: "movingBorderAnimation")
    }
    
    private func removeMovingBorder() {
        animatedBorderLayer.strokeColor = UIColor.clear.cgColor
        animatedBorderLayer.removeAllAnimations()
    }
}

