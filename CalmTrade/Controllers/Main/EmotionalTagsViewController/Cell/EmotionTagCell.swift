//
//  EmotionTagCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 28/08/25.
//

import UIKit

final class EmotionTagCell: UICollectionViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var mainView: UIView!
    @IBOutlet weak var btnSelect: UIButton!

    static let reuseIdentifier = "EmotionTagCell"

    // MARK: - Layers (created once)
    private let gradientLayer = CAGradientLayer()     // static gradient border
    private let borderMask    = CAShapeLayer()        // mask for gradient
    private let movingLayer   = CAShapeLayer()        // animated “runner”

    // State
    private var selectionColor: UIColor = .systemGreen
    private var isTagSelected = false
    private var animationRunning = false

    // Config
    private let baseBorderWidth: CGFloat = 1
    private let animatedBorderWidth: CGFloat = 2
    private let cornerInset: CGFloat = 1 // small inset to avoid clipping

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // Stop animation and remove dynamic layers; keep default border
        removeMovingBorder()
        animationRunning = false

        gradientLayer.removeFromSuperlayer()
        gradientLayer.mask = nil

        // reset UI state
        isTagSelected = false
        titleLabel.textColor = .lightGray
        mainView.layer.shadowOpacity = 0
        mainView.layer.borderWidth = baseBorderWidth
        mainView.layer.borderColor = UIColor(hex: "313131").cgColor
    }
    
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)

        // When cell is coming back onscreen, refresh layout + animation
        if newWindow != nil, isTagSelected {
            setNeedsLayout()
            layoutIfNeeded()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard mainView.bounds.width > 0, mainView.bounds.height > 0 else { return }

        // Pill shape
        mainView.layer.cornerRadius = mainView.bounds.height / 2

        // Update path/frame for mask & moving layer
        let lineInset = max(animatedBorderWidth, baseBorderWidth) / 2 + cornerInset
        let rect = mainView.bounds.insetBy(dx: lineInset, dy: lineInset)
        let roundedPath = UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2).cgPath

        // gradient layer covers mainView bounds and is masked by borderMask
        gradientLayer.frame = mainView.bounds
        borderMask.frame = mainView.bounds
        borderMask.path = roundedPath
        borderMask.lineWidth = 1.0//animatedBorderWidth
        borderMask.fillColor = UIColor.clear.cgColor
        borderMask.strokeColor = UIColor.black.cgColor

        // moving layer uses same path (centerline)
        movingLayer.frame = mainView.bounds
        movingLayer.path = roundedPath
        movingLayer.lineWidth = animatedBorderWidth
        movingLayer.lineCap = .round
        movingLayer.fillColor = UIColor.clear.cgColor
        movingLayer.strokeColor = selectionColor.cgColor
    }

    func configure(with title: String, color: UIColor) {
        titleLabel.text = title
        selectionColor = color
    }

    func updateSelection(isSelected: Bool) {
        isTagSelected = isSelected

        if isSelected {
            titleLabel.textColor = .white

            // Add gradient border if not present
            if gradientLayer.superlayer == nil {
                gradientLayer.name = "gradientBorder"
                gradientLayer.colors = [
                    selectionColor.cgColor,
                    selectionColor.cgColor
//                    selectionColor.cgColor,
//                    UIColor.white.cgColor
                ]
                gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
                gradientLayer.endPoint   = CGPoint(x: 1, y: 0.5)
                gradientLayer.mask = borderMask
                mainView.layer.addSublayer(gradientLayer)
            }

            // make sure layout is refreshed and animation starts after layout pass
            setNeedsLayout()
            layoutIfNeeded()

            // shadow
            mainView.backgroundColor = selectionColor.withAlphaComponent(0.6)
            mainView.layer.shadowColor = selectionColor.cgColor
            mainView.layer.shadowOpacity = 0.35
            mainView.layer.shadowOffset = .zero
            mainView.layer.shadowRadius = 4.8
            mainView.layer.borderWidth = 0
        } else {
            titleLabel.textColor = .lightGray
            mainView.layer.shadowOpacity = 0
            mainView.layer.borderWidth = baseBorderWidth
            mainView.layer.borderColor = UIColor(hex: "313131").cgColor
            mainView.backgroundColor = .clear

            gradientLayer.removeFromSuperlayer()
            gradientLayer.mask = nil
        }

        // ensure final layout
        setNeedsLayout()
    }

    private func setupUI() {
        mainView.layer.masksToBounds = false
        mainView.backgroundColor = .clear
        mainView.layer.borderWidth = baseBorderWidth
        mainView.layer.borderColor = UIColor(hex: "313131").cgColor

        // pre-config for moving layer (not added until selection)
        movingLayer.lineWidth = animatedBorderWidth
        movingLayer.fillColor = UIColor.clear.cgColor
        movingLayer.lineCap = .round
    }

    // MARK: - Animation
    private func addMovingBorder() {
        guard movingLayer.superlayer == nil else {
            // already added; if animation missing, (re)start it
            if movingLayer.animation(forKey: "runner") == nil {
                runStrokeAnimation()
            }
            return
        }
        // ensure gradient is present (masking works)
        if gradientLayer.superlayer == nil {
            gradientLayer.mask = borderMask
            mainView.layer.addSublayer(gradientLayer)
        }
        mainView.layer.addSublayer(movingLayer)
        runStrokeAnimation()
    }
    
    private func runStrokeAnimation() {
        animationRunning = true
        movingLayer.removeAllAnimations()
        movingLayer.lineDashPattern = nil
        
        let segmentLength: CGFloat = 0.5   // 50% of circumference
        let overshoot: CGFloat = 0.55      // bounce stretch
        
        // --- Slide Start ---
        let slideStart = CABasicAnimation(keyPath: "strokeStart")
        slideStart.fromValue = 0.0
        slideStart.toValue = 1.0 - segmentLength
        slideStart.duration = 2.0
        slideStart.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // --- Slide End ---
        let slideEnd = CABasicAnimation(keyPath: "strokeEnd")
        slideEnd.fromValue = segmentLength
        slideEnd.toValue = 1.0
        slideEnd.duration = 2.0
        slideEnd.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // --- Bounce (stretch at end, before looping) ---
        let bounceEnd = CABasicAnimation(keyPath: "strokeEnd")
        bounceEnd.fromValue = 1.0
        bounceEnd.toValue = overshoot
        bounceEnd.beginTime = slideEnd.duration
        bounceEnd.duration = 0.25
        bounceEnd.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        let relaxEnd = CABasicAnimation(keyPath: "strokeEnd")
        relaxEnd.fromValue = overshoot
        relaxEnd.toValue = 1.0
        relaxEnd.beginTime = bounceEnd.beginTime + bounceEnd.duration
        relaxEnd.duration = 0.25
        relaxEnd.timingFunction = CAMediaTimingFunction(name: .easeIn)
        
        // --- Group ---
        let group = CAAnimationGroup()
        group.animations = [slideStart, slideEnd, bounceEnd, relaxEnd]
        group.duration = relaxEnd.beginTime + relaxEnd.duration
        group.repeatCount = .infinity
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        
        // 🔑 Initial visible segment
        movingLayer.strokeStart = 0.0
        movingLayer.strokeEnd = segmentLength
        
        movingLayer.add(group, forKey: "seamlessCalmStroke")
    }



//    private func runStrokeAnimation() {
//        animationRunning = true
//        movingLayer.removeAllAnimations()
//
//        let head = CABasicAnimation(keyPath: "strokeEnd")
//        head.fromValue = 0.0
//        head.toValue = 1.0
//        head.duration = 1.6
//        head.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
//
//        let tail = CABasicAnimation(keyPath: "strokeStart")
//        tail.fromValue = 0.0
//        tail.toValue = 1.0
//        tail.duration = 1.6
//        tail.beginTime = 0.6
//        tail.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
//
//        let group = CAAnimationGroup()
//        group.animations = [head, tail]
//        group.duration = 2.2
//        group.repeatCount = .infinity
//        group.isRemovedOnCompletion = false
//
//        movingLayer.add(group, forKey: "runner")
//    }

    private func removeMovingBorder() {
        animationRunning = false
        movingLayer.removeAllAnimations()
        movingLayer.removeFromSuperlayer()
    }
}


