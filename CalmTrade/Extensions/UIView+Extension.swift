//
//  UIView+Extension.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/08/25.
//

import UIKit

/// This extension makes UIView and its subclasses (like UILabel, UIImageView, UIButton) designable in Interface Builder.
/// It adds properties for corner radius, border, and shadow that can be set directly in the Storyboard.
@IBDesignable
extension UIView {

    // MARK: - Corner Radius

    /// Exposes the `cornerRadius` property of the view's layer to Interface Builder.
    @IBInspectable
    var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            // If you set a corner radius, you often want to clip the contents.
            // Note: This will clip the outer shadow. If you need both, use a container view for the shadow.
            if newValue > 0 {
                layer.masksToBounds = true
            }
        }
    }

    // MARK: - Border

    /// Exposes the `borderWidth` property of the view's layer to Interface Builder.
    @IBInspectable
    var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }

    /// Exposes the `borderColor` property of the view's layer to Interface Builder.
    @IBInspectable
    var borderColor: UIColor? {
        get {
            guard let color = layer.borderColor else { return nil }
            return UIColor(cgColor: color)
        }
        set {
            layer.borderColor = newValue?.cgColor
        }
    }

    // MARK: - Outer Shadow

    /// Exposes the `shadowColor` property of the view's layer to Interface Builder for an outer shadow.
    @IBInspectable
    var shadowColor: UIColor? {
        get {
            guard let color = layer.shadowColor else { return nil }
            return UIColor(cgColor: color)
        }
        set {
            layer.shadowColor = newValue?.cgColor
        }
    }

    /// Exposes the `shadowOpacity` property of the view's layer to Interface Builder.
    @IBInspectable
    var shadowOpacity: Float {
        get {
            return layer.shadowOpacity
        }
        set {
            layer.shadowOpacity = newValue
        }
    }

    /// Exposes the `shadowOffset` property of the view's layer to Interface Builder.
    @IBInspectable
    var shadowOffset: CGSize {
        get {
            return layer.shadowOffset
        }
        set {
            layer.shadowOffset = newValue
        }
    }

    /// Exposes the `shadowRadius` property of the view's layer to Interface Builder.
    @IBInspectable
    var shadowRadius: CGFloat {
        get {
            return layer.shadowRadius
        }
        set {
            // For outer shadows to be visible, `masksToBounds` must be false.
            layer.masksToBounds = false
            layer.shadowRadius = newValue
        }
    }
}
