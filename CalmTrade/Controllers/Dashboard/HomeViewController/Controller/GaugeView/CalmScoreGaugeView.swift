//
//  CalmScoreGaugeView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 28/08/25.
//

import UIKit
import Foundation

@IBDesignable
class CalmScoreGaugeView: UIView {
    
    // MARK:- @IBInspectable
    @IBInspectable public var colorCodes: String = "008E3E,429A2D,F0BB00,F0BB00,F59304,F2220D"
    @IBInspectable public var areas: String = "20,20,20,20,20"
    @IBInspectable public var arcAngle: CGFloat = 2.4
    
    @IBInspectable public var needleColor: UIColor = UIColor(red: 18/255.0, green: 112/255.0, blue: 178/255.0, alpha: 1.0)
    @IBInspectable public var needleValue: CGFloat = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    @IBInspectable public var applyShadow: Bool = true {
        didSet {
            shadowColor = applyShadow ? shadowColor : UIColor.clear
        }
    }
    
    @IBInspectable public var isRoundCap: Bool = true {
        didSet {
            capStyle = isRoundCap ? .round : .butt
        }
    }
    
    @IBInspectable public var blinkAnimate: Bool = false
    
    @IBInspectable public var circleColor: UIColor = UIColor.black
    
    var firstAngle = CGFloat()
    var capStyle = CGLineCap.round
    
    // MARK:- UIView Draw method
    override public func draw(_ rect: CGRect) {
        drawGauge()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        drawGauge()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        drawGauge()
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        drawGauge()
    }
    
    // MARK:- Custom Methods
    func drawGauge() {
        layer.sublayers = []
        drawSmartArc()
        drawPointer()
        drawTicks()
    }
    
//    func drawSmartArc() {
//        let arcColors = colorCodes.components(separatedBy: ",").map { UIColor($0) }
//        let areaValues = areas.components(separatedBy: ",").compactMap { CGFloat(Double($0) ?? 0) }
//        let total = areaValues.reduce(0, +)
//        
//        let lineWidth: CGFloat = bounds.height / 5
//        let radius: CGFloat = (bounds.width - lineWidth) / 2
//        let center = CGPoint(x: bounds.midX, y: bounds.maxY)
//        
//        var startAngle: CGFloat = .pi // left bottom
//        for (index, value) in areaValues.enumerated() {
//            let fraction = value / total
//            let arcLength = CGFloat.pi * fraction
//            let endAngle = startAngle + arcLength
//            
//            let path = UIBezierPath(
//                arcCenter: center,
//                radius: radius,
//                startAngle: startAngle,
//                endAngle: endAngle,
//                clockwise: true
//            )
//            
//            let arcLayer = CAShapeLayer()
//            arcLayer.path = path.cgPath
//            arcLayer.lineWidth = lineWidth
//            arcLayer.lineCap = .butt
//            arcLayer.strokeColor = arcColors[index].cgColor
//            arcLayer.fillColor = UIColor.clear.cgColor
//            layer.addSublayer(arcLayer)
//            
//            startAngle = endAngle
//        }
//    }
    
    func drawSmartArc() {
        let colors = colorCodes
            .components(separatedBy: ",")
            .map { UIColor($0).cgColor }

        let lineWidth: CGFloat = bounds.height / 5
        
        // ✅ Inset radius so stroke doesn't get cut
        let radius: CGFloat = (bounds.width - lineWidth) / 2 - 4
        let center = CGPoint(x: bounds.midX, y: bounds.maxY)

        let path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: .pi,
            endAngle: 0,
            clockwise: true
        )
        
        let arcShape = CAShapeLayer()
        arcShape.path = path.cgPath
        arcShape.lineWidth = lineWidth
        arcShape.lineCap = .round   // ✅ rounded ends
        arcShape.strokeColor = UIColor.black.cgColor
        arcShape.fillColor = UIColor.clear.cgColor
        
        let gradient = CAGradientLayer()
        gradient.frame = bounds.insetBy(dx: 0, dy: -lineWidth/2) // extend slightly to cover top
        gradient.colors = colors
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint   = CGPoint(x: 1, y: 1)
        
        gradient.mask = arcShape
        layer.addSublayer(gradient)
    }




    
    func drawPointer() {
        // Remove old pointer
        layer.sublayers?.removeAll(where: { $0.name == "pointerLayer" })
        
        let lineWidth: CGFloat = bounds.height / 5   // same as arc stroke
        let rectWidth: CGFloat = lineWidth * 1.5    // length across stroke
        let rectHeight: CGFloat = 8//lineWidth * 0.9        // must match stroke thickness
        
        let pointerLayer = CAShapeLayer()
        pointerLayer.name = "pointerLayer"
        
        // Rectangle sized to arc stroke thickness
        let rectPath = UIBezierPath(
            roundedRect: CGRect(x: -rectWidth/2, y: -rectHeight/2, width: rectWidth, height: rectHeight),
            cornerRadius: 0//rectHeight/2
        )
        pointerLayer.path = rectPath.cgPath
        pointerLayer.fillColor = UIColor.init("#191919").cgColor//needleColor.cgColor
        
        // ✅ Use the same radius as arc *center line*
        let radius: CGFloat = (bounds.width - lineWidth) / 2
        let center = CGPoint(x: bounds.midX, y: bounds.maxY)
        
        // Map 0–100 → π (left) to 0 (right)
        let angle = .pi + (CGFloat.pi * (needleValue / 100))
        
        // Position pointer at arc centerline
        let x = center.x + radius * cos(angle)
        let y = center.y + radius * sin(angle)
        pointerLayer.position = CGPoint(x: x, y: y)
        
        // ✅ Rotate so it cuts across arc thickness
        pointerLayer.setAffineTransform(CGAffineTransform(rotationAngle: angle))
        
        layer.addSublayer(pointerLayer)
    }

    func drawTicks() {
        // Remove old ticks + labels
        layer.sublayers?.removeAll(where: { $0.name == "tickLayer" })
        subviews.forEach { if $0.tag == 999 { $0.removeFromSuperview() } }

        let lineWidth: CGFloat = bounds.height / 5
        let radius: CGFloat = (bounds.width - lineWidth) / 2
        let center = CGPoint(x: bounds.midX, y: bounds.maxY)

        for value in stride(from: 8, through: 98, by: 10) {
            let progress = CGFloat(value) / 100
            let angle = .pi + (CGFloat.pi * progress)

            // --- Distances ---
            let tickOffset: CGFloat = -24      // distance between arc and tick
            let labelOffset: CGFloat = -31    // distance between tick and label

            // --- Tick as Rectangle ---
            let tickLength: CGFloat = 12
            let tickThickness: CGFloat = 3

            let tx = center.x + (radius + tickOffset) * cos(angle)
            let ty = center.y + (radius + tickOffset) * sin(angle)

            let tickRect = CGRect(
                x: -tickLength/2,
                y: -tickThickness/2,
                width: tickLength,
                height: tickThickness
            )
            let tickPath = UIBezierPath(roundedRect: tickRect, cornerRadius: tickThickness/2)

            let tickLayer = CAShapeLayer()
            tickLayer.name = "tickLayer"
            tickLayer.path = tickPath.cgPath
            tickLayer.fillColor = UIColor.white.cgColor
            tickLayer.position = CGPoint(x: tx, y: ty)
            tickLayer.setAffineTransform(CGAffineTransform(rotationAngle: angle))
            layer.addSublayer(tickLayer)

            // --- Label ---
            let labelRadius = radius + tickOffset + tickLength/2 + labelOffset
            let lx = center.x + labelRadius * cos(angle)
            let ly = center.y + labelRadius * sin(angle)

            let label = UILabel(frame: CGRect(x: lx - 15, y: ly - 10, width: 30, height: 20))
            label.text = "\(value + 2)"
            label.textColor = .white
            label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            label.textAlignment = .center
            label.tag = 999
            addSubview(label)
        }
    }



    
    func blink() {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0.2
        animation.duration = 0.1
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.default)
        animation.autoreverses = true
        animation.repeatCount = 3
        self.layer.add(animation, forKey: "opacity")
    }
    
    func radian(for area: CGFloat) -> CGFloat {
        let degrees = arcAngle * area
        let radians = degrees * .pi/180
        return radians
    }
    
    func getAllAngles() -> [CGFloat] {
        var angles = [CGFloat]()
        firstAngle = radian(for: 0) + .pi/2
        var lastAngle = radian(for: 100) + .pi/2
        
        let degrees:CGFloat = 3.6 * 100
        let radians = degrees * .pi/(1.8*100)
        
        let thisRadians = (arcAngle * 100) * .pi/(1.8*100)
        let theD = (radians - thisRadians)/2
        firstAngle += theD
        lastAngle += theD
        
        angles.append(firstAngle)
        let allAngles = self.areas.components(separatedBy: ",")
        for index in 0..<allAngles.count {
            let n = NumberFormatter().number(from: allAngles[index])
            let angle = radian(for: CGFloat(truncating: n!)) + angles[index]
            angles.append(angle)
        }
        
        angles.append(lastAngle)
        return angles
    }
    
    func createArcWith(startAngle: CGFloat, endAngle: CGFloat, arcCap: CGLineCap, strokeColor: UIColor, center: CGPoint) {
        let lineWidth: CGFloat = bounds.height / 5  // thickness relative to height
        
        // Make arc radius such that outer edge touches view bounds
        let radius: CGFloat = (min(bounds.width, bounds.height) - lineWidth) / 2
        
        let path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.maxY), // bottom center of view
            radius: (bounds.width - lineWidth) / 2,
            startAngle: .pi,           // 180°
            endAngle: 0,               // 0°
            clockwise: true
        )
        
        let arcLayer = CAShapeLayer()
        arcLayer.path = path.cgPath
        arcLayer.lineWidth = lineWidth
        arcLayer.lineCap = CAShapeLayerLineCap(from: arcCap)
        arcLayer.strokeColor = strokeColor.cgColor
        arcLayer.fillColor = UIColor.clear.cgColor
        
        layer.addSublayer(arcLayer)
    }

    
    func drawNeedleCircle() {
        // 1
        let circleLayer = CAShapeLayer()
        let circlePath = UIBezierPath(arcCenter: CGPoint(x: bounds.width / 2, y: bounds.height / 2), radius: self.bounds.width/20, startAngle: 0.0, endAngle: CGFloat(2 * Double.pi), clockwise: false)
        // 2
        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = circleColor.cgColor
        layer.addSublayer(circleLayer)
    }
    
    func drawNeedle() {
        // 1
        let triangleLayer = CAShapeLayer()
        let shadowLayer = CAShapeLayer()
        
        // 2
        triangleLayer.frame = bounds
        shadowLayer.frame = CGRect(x: bounds.origin.x, y: bounds.origin.y + 5, width: bounds.width, height: bounds.height)
        
        // 3
        let needlePath = UIBezierPath()
        needlePath.move(to: CGPoint(x: self.bounds.width/2, y: self.bounds.width * 0.95))
        needlePath.addLine(to: CGPoint(x: self.bounds.width * 0.47, y: self.bounds.width * 0.42))
        needlePath.addLine(to: CGPoint(x: self.bounds.width * 0.53, y: self.bounds.width * 0.42))
        
        needlePath.close()
        
        // 4
        triangleLayer.path = needlePath.cgPath
        shadowLayer.path = needlePath.cgPath
        
        // 5
        triangleLayer.fillColor = needleColor.cgColor
        triangleLayer.strokeColor = needleColor.cgColor
//        shadowLayer.fillColor = shadowColor.cgColor
        // 6
        layer.addSublayer(shadowLayer)
        layer.addSublayer(triangleLayer)
        
        var firstAngle = radian(for: 0)
        
        let degrees:CGFloat = 3.6 * 100 // Entire Arc is of 240 degrees
        let radians = degrees * .pi/(1.8*100)
        
        let thisRadians = (arcAngle * 100) * .pi/(1.8*100)
        let theD = (radians - thisRadians)/2
        firstAngle += theD
        let needleValue = radian(for: self.needleValue) + firstAngle
        animate(triangleLayer: triangleLayer, shadowLayer: shadowLayer, fromValue: 0, toValue: needleValue*1.05, duration: 0.5) {
            self.animate(triangleLayer: triangleLayer, shadowLayer: shadowLayer, fromValue: needleValue*1.05, toValue: needleValue*0.95, duration: 0.4, callBack: {
                self.animate(triangleLayer: triangleLayer, shadowLayer: shadowLayer, fromValue: needleValue*0.95, toValue: needleValue, duration: 0.6, callBack: {})
            })
        }
    }
    
    func animate(triangleLayer: CAShapeLayer, shadowLayer:CAShapeLayer, fromValue: CGFloat, toValue:CGFloat, duration: CFTimeInterval, callBack:@escaping ()->Void) {
        // 1
        CATransaction.begin()
        let spinAnimation1 = CABasicAnimation(keyPath: "transform.rotation.z")
        spinAnimation1.fromValue = fromValue//radian(for: fromValue)
        spinAnimation1.toValue = toValue//radian(for: toValue)
        spinAnimation1.duration = duration
        spinAnimation1.fillMode = CAMediaTimingFillMode.forwards
        spinAnimation1.isRemovedOnCompletion = false
        
        CATransaction.setCompletionBlock {
            callBack()
        }
        // 2
        triangleLayer.add(spinAnimation1, forKey: "indeterminateAnimation")
        shadowLayer.add(spinAnimation1, forKey: "indeterminateAnimation")
        CATransaction.commit()
    }
}

struct ArcModel {
    var startAngle: CGFloat!
    var endAngle: CGFloat!
    var strokeColor: UIColor!
    var arcCap: CGLineCap!
    var center: CGPoint!
}

extension Array {
    mutating func rearrange(from: Int, to: Int) {
        precondition(from != to && indices.contains(from) && indices.contains(to), "invalid indexes")
        insert(remove(at: from), at: to)
    }
}

extension CAShapeLayerLineCap {
    init(from cgCap: CGLineCap) {
        switch cgCap {
        case .butt: self = .butt
        case .round: self = .round
        case .square: self = .square
        @unknown default: self = .butt
        }
    }
}
