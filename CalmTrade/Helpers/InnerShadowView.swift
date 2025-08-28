//
//  InnerShadowView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/08/25.
//

import UIKit

/// A custom, designable UIView subclass that provides inspectable properties for multiple inner shadows.
/// To use, set the custom class of a UIView in your Storyboard to `InnerShadowView`.
@IBDesignable
class InnerShadowView: UIView {

    private static let innerShadow1LayerName = "innerShadowLayer1"
    private static let innerShadow2LayerName = "innerShadowLayer2"
    
    // MARK: - Inner Shadow 1 Properties

    /// Toggles the first inner shadow on or off.
    @IBInspectable
    var hasInnerShadow1: Bool = false {
        didSet {
            updateInnerShadows()
        }
    }

    /// The color of the first inner shadow.
    @IBInspectable
    var innerShadowColor1: UIColor = UIColor.black {
        didSet {
            updateInnerShadows()
        }
    }

    /// The opacity of the first inner shadow (0.0 to 1.0).
    @IBInspectable
    var innerShadowOpacity1: Float = 0.5 {
        didSet {
            updateInnerShadows()
        }
    }
    
    /// The X-axis offset of the first inner shadow.
    @IBInspectable
    var innerShadowX1: CGFloat = 0 {
        didSet {
            updateInnerShadows()
        }
    }
    
    /// The Y-axis offset of the first inner shadow.
    @IBInspectable
    var innerShadowY1: CGFloat = 2 {
        didSet {
            updateInnerShadows()
        }
    }

    /// The blur radius of the first inner shadow.
    @IBInspectable
    var innerShadowRadius1: CGFloat = 4.0 {
        didSet {
            updateInnerShadows()
        }
    }
    
    // MARK: - Inner Shadow 2 Properties

    /// Toggles the second inner shadow on or off.
    @IBInspectable
    var hasInnerShadow2: Bool = false {
        didSet {
            updateInnerShadows()
        }
    }

    /// The color of the second inner shadow.
    @IBInspectable
    var innerShadowColor2: UIColor = UIColor.black {
        didSet {
            updateInnerShadows()
        }
    }

    /// The opacity of the second inner shadow (0.0 to 1.0).
    @IBInspectable
    var innerShadowOpacity2: Float = 0.5 {
        didSet {
            updateInnerShadows()
        }
    }
    
    /// The X-axis offset of the second inner shadow.
    @IBInspectable
    var innerShadowX2: CGFloat = 0 {
        didSet {
            updateInnerShadows()
        }
    }
    
    /// The Y-axis offset of the second inner shadow.
    @IBInspectable
    var innerShadowY2: CGFloat = 2 {
        didSet {
            updateInnerShadows()
        }
    }

    /// The blur radius of the second inner shadow.
    @IBInspectable
    var innerShadowRadius2: CGFloat = 4.0 {
        didSet {
            updateInnerShadows()
        }
    }

    // MARK: - Lifecycle

    /// Ensures the inner shadows are redrawn if the view's size changes.
    override func layoutSubviews() {
        super.layoutSubviews()
        updateInnerShadows()
    }

    // MARK: - Private Methods
    
    private func updateInnerShadows() {
        // Remove existing shadows first to prevent duplicates
        removeInnerShadow(withName: InnerShadowView.innerShadow1LayerName)
        removeInnerShadow(withName: InnerShadowView.innerShadow2LayerName)
        
        // Apply shadows if they are enabled
        if hasInnerShadow1 {
            let offset = CGSize(width: innerShadowX1, height: innerShadowY1)
            applyInnerShadow(
                name: InnerShadowView.innerShadow1LayerName,
                color: innerShadowColor1,
                opacity: innerShadowOpacity1,
                offset: offset,
                radius: innerShadowRadius1
            )
        }
        
        if hasInnerShadow2 {
            let offset = CGSize(width: innerShadowX2, height: innerShadowY2)
            applyInnerShadow(
                name: InnerShadowView.innerShadow2LayerName,
                color: innerShadowColor2,
                opacity: innerShadowOpacity2,
                offset: offset,
                radius: innerShadowRadius2
            )
        }
    }
    
    private func applyInnerShadow(name: String, color: UIColor, opacity: Float, offset: CGSize, radius: CGFloat) {
        let innerShadowLayer = CALayer()
        innerShadowLayer.name = name
        innerShadowLayer.frame = bounds
        innerShadowLayer.masksToBounds = true
        innerShadowLayer.shadowColor = color.cgColor
        innerShadowLayer.shadowOffset = offset
        innerShadowLayer.shadowOpacity = opacity
        innerShadowLayer.shadowRadius = radius
        
        // Create a path with a hole in it that's larger than the view
        let path = UIBezierPath(rect: bounds.insetBy(dx: -radius * 2, dy: -radius * 2))
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

    private func removeInnerShadow(withName name: String) {
        layer.sublayers?.filter({ $0.name == name }).forEach({ $0.removeFromSuperlayer() })
    }
}
