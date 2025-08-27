//
//  UIColor+Hex.swift
//
//  Created by Surjeet Singh
//  Copyright © 2017 Surjeet Singh. All rights reserved.
//

import UIKit

extension UIColor {

     convenience init(_ hexString: String) {
        var hex = hexString
        if hex.hasPrefix("#") {
            hex = String(hex.dropFirst())
        }
        
        let hexVal = Int(hex, radix: 16)!
        self.init(red:CGFloat( (hexVal & 0xFF0000) >> 16 ) / 255.0,
                  green: CGFloat( (hexVal & 0x00FF00) >> 8 ) / 255.0,
                  blue: CGFloat( (hexVal & 0x0000FF) >> 0 ) / 255.0,
                  alpha: 1.0)

    }
    
    static func getRandomColor() -> UIColor{
        //Generate between 0 to 1
        let red:CGFloat = CGFloat(drand48())
        let green:CGFloat = CGFloat(drand48())
        let blue:CGFloat = CGFloat(drand48())
        
        return UIColor(red:red, green: green, blue: blue, alpha: 1.0)
    }
   
    var hexString:NSString {
        let colorRef = self.cgColor.components
        let r:CGFloat = colorRef![0]
        let g:CGFloat = colorRef![1]
        let b:CGFloat = colorRef![2]
        return NSString(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
    }
    
    static func gradientColorFromTwoColor(_ firstColor:UIColor, _ secondColor:UIColor, _ resultColorCount:Int) -> [UIColor] {
        var colorArray = [UIColor]()
        let r1 = firstColor.redValue, g1 = firstColor.greenValue, b1 = firstColor.blueValue, a1 = firstColor.alphaValue
        let r2 = secondColor.redValue, g2 = secondColor.greenValue, b2 = secondColor.blueValue, a2 = secondColor.alphaValue
        
        colorArray.append(firstColor)
        let count = CGFloat(resultColorCount-2)
        for j in 1..<resultColorCount {
            let i = CGFloat(j)
            let color = UIColor(red:r1+i*((r2-r1)/count), green:g1+i*((g2-g1)/count), blue:b1+i*((b2-b1)/count), alpha:a1+i*((a2-a1)/count))
            colorArray.append(color)
        }
        colorArray.append(secondColor)
        return colorArray
    }
    
    static func gradientColorFromColors(_ firstColor:UIColor, _ secondColor:UIColor, _ index:Int, _ maxCount:Int) -> UIColor {
        let r1 = firstColor.redValue, g1 = firstColor.greenValue, b1 = firstColor.blueValue, a1 = firstColor.alphaValue
        let r2 = secondColor.redValue, g2 = secondColor.greenValue, b2 = secondColor.blueValue, a2 = secondColor.alphaValue

        if index == 0 {
            return firstColor
        }
        if index == maxCount-1 {
            return secondColor
        }

        let count = CGFloat(maxCount)
        let idx = CGFloat(index)
        
        let color = UIColor(red:r1+idx*((r2-r1)/count), green:g1+idx*((g2-g1)/count), blue:b1+idx*((b2-b1)/count), alpha:a1+idx*((a2-a1)/count))
        return color
    }
    
}

extension UIColor {
    var redValue: CGFloat{ return CIColor(color: self).red }
    var greenValue: CGFloat{ return CIColor(color: self).green }
    var blueValue: CGFloat{ return CIColor(color: self).blue }
    var alphaValue: CGFloat{ return CIColor(color: self).alpha }
}

