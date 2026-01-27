//
//  UIFont+Fallback.swift
//  CalmTrade
//
//  Created by Developer on 1/24/26.
//

import UIKit

extension UIFont {
    /// Safely creates a font with fallback to system font if the requested font is not available
    static func safeSystemFont(ofSize fontSize: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        // Try to create the requested font
        let systemFont = UIFont.systemFont(ofSize: fontSize, weight: weight)
        return systemFont
    }
    
    /// Safely creates a font with a specific name, falling back to system font if unavailable
    static func safeFontNamed(_fontName: String, size: CGFloat) -> UIFont {
        if let font = UIFont(name: _fontName, size: size) {
            return font
        } else {
            // Fallback to system font if the named font isn't available
            print("Warning: Font '\(_fontName)' not available, falling back to system font")
            return UIFont.systemFont(ofSize: size)
        }
    }
    
    /// Checks if a specific font family is available on the device
    static func isFontFamilyAvailable(_ fontFamily: String) -> Bool {
        for familyName in UIFont.familyNames {
            if familyName.lowercased() == fontFamily.lowercased() {
                return UIFont.fontNames(forFamilyName: familyName).count > 0
            }
        }
        return false
    }
}