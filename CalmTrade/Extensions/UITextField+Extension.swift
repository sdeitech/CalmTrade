//
//  UITextField+Extension.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/08/25.
//


import UIKit

/// This extension adds an inspectable property to UITextField, allowing the placeholder
/// color to be set directly from the Storyboard's Attributes Inspector.
@IBDesignable
extension UITextField {

    /// Exposes a `placeholderColor` property to Interface Builder.
    /// This allows you to set the color of the placeholder text directly in the Storyboard.
    @IBInspectable
    var placeholderColor: UIColor? {
        get {
            // Attempt to retrieve the color from the attributed placeholder text.
            // Note: This getter will only work if the color was previously set using this setter.
            return self.attributedPlaceholder?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        }
        set {
            // Ensure we have a placeholder string to apply the color to.
            guard let placeholder = self.placeholder, let color = newValue else {
                // If there's no placeholder or no color, do nothing.
                return
            }
            
            // Create an attributed string with the new color.
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: color,
                .font: self.font ?? UIFont.systemFont(ofSize: 14) // Use the text field's font or a default.
            ]
            
            self.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: attributes)
        }
    }
}

// MARK: - How to Use

/*
 1.  Add this Swift file (`UITextField+Placeholder.swift`) to your project.
 2.  Go to your Storyboard or .xib file.
 3.  Select any UITextField.
 4.  Make sure you have set some text in the "Placeholder" field in the Attributes Inspector.
 5.  You will now see a new property at the top of the Attributes Inspector called "Placeholder Color".
 6.  Click the color swatch to choose a color, and it will be applied to your text field's placeholder.
*/
