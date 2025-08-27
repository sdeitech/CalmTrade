//
//  InnerShadowView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/08/25.
//

import UIKit

@IBDesignable
class InnerShadowView: UIView {

    private static let innerShadowLayerName = "innerShadowLayer"
    
    // MARK: - Inner Shadow Properties

    /// Toggles the inner shadow on or off.
    @IBInspectable
    var hasInnerShadow: Bool = false {
        didSet {
            updateInnerShadow()
        }
    }

    /// The color of the inner shadow.
    @IBInspectable
    var innerShadowColor: UIColor = UIColor.black {
        didSet {
            updateInnerShadow()
        }
    }

    /// The opacity of the inner shadow (0.0 to 1.0).
    @IBInspectable
    var innerShadowOpacity: Float = 0.5 {
        didSet {
            updateInnerShadow()
        }
    }
    
    /// The offset (x, y) of the inner shadow.
    @IBInspectable
    var innerShadowOffset: CGSize = CGSize(width: 0, height: 2) {
        didSet {
            updateInnerShadow()
        }
    }

    /// The blur radius of the inner shadow.
    @IBInspectable
    var innerShadowRadius: CGFloat = 4.0 {
        didSet {
            updateInnerShadow()
        }
    }

    // MARK: - Lifecycle

    /// Ensures the inner shadow is redrawn if the view's size changes.
    override func layoutSubviews() {
        super.layoutSubviews()
        updateInnerShadow()
    }

    // MARK: - Private Methods

    private func updateInnerShadow() {
        if hasInnerShadow {
            applyInnerShadow()
        } else {
            removeInnerShadow()
        }
    }
    
    private func applyInnerShadow() {
        // Remove existing shadow before adding a new one to prevent duplicates
        removeInnerShadow()

        let innerShadowLayer = CALayer()
        innerShadowLayer.name = InnerShadowView.innerShadowLayerName
        innerShadowLayer.frame = bounds
        innerShadowLayer.masksToBounds = true
        innerShadowLayer.shadowColor = innerShadowColor.cgColor
        innerShadowLayer.shadowOffset = innerShadowOffset
        innerShadowLayer.shadowOpacity = innerShadowOpacity
        innerShadowLayer.shadowRadius = innerShadowRadius
        
        // Create a path with a hole in it that's larger than the view
        let path = UIBezierPath(rect: bounds.insetBy(dx: -innerShadowRadius * 2, dy: -innerShadowRadius * 2))
        let innerPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius)
        path.append(innerPath)
        path.usesEvenOddFillRule = true

        // Use the path as a mask
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd
        
        innerShadowLayer.mask = maskLayer
        
        // The view must clip its contents for the inner shadow to work
        layer.masksToBounds = true
        
        layer.addSublayer(innerShadowLayer)
    }

    private func removeInnerShadow() {
        layer.sublayers?.filter({ $0.name == InnerShadowView.innerShadowLayerName }).forEach({ $0.removeFromSuperlayer() })
    }
}
