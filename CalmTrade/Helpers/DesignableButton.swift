import UIKit

/// A custom, designable UIButton subclass that provides inspectable properties for a gradient background and multiple inner shadows.
/// To use, set the custom class of a UIButton in your Storyboard to `DesignableButton`.
@IBDesignable
class DesignableButton: UIButton {

    private static let innerShadow1LayerName = "innerShadowLayer1"
    private static let innerShadow2LayerName = "innerShadowLayer2"
    private let gradientLayer = CAGradientLayer()

    // MARK: - Gradient Properties

    /// The starting color of the gradient.
    @IBInspectable
    var startColor: UIColor = UIColor.blue {
        didSet {
            updateGradient()
        }
    }

    /// The ending color of the gradient.
    @IBInspectable
    var endColor: UIColor = UIColor.cyan {
        didSet {
            updateGradient()
        }
    }

    /// If true, the gradient is horizontal (left to right). If false, it's vertical (top to bottom).
    @IBInspectable
    var isHorizontalGradient: Bool = true {
        didSet {
            updateGradient()
        }
    }
    
    // MARK: - Inner Shadow 1 Properties (e.g., Top-Left)

    /// Toggles the first inner shadow on or off.
    @IBInspectable
    var hasShadow1: Bool = false {
        didSet {
            updateInnerShadows()
        }
    }

    /// The color of the first inner shadow.
    @IBInspectable
    var shadowColor1: UIColor = UIColor.white {
        didSet {
            updateInnerShadows()
        }
    }

    /// The opacity of the first inner shadow (0.0 to 1.0).
    @IBInspectable
    var opacity1: Float = 0.25 {
        didSet {
            updateInnerShadows()
        }
    }
    
    /// The X-axis offset of the first inner shadow.
    @IBInspectable
    var X1: CGFloat = -2.78 {
        didSet {
            updateInnerShadows()
        }
    }
    
    /// The Y-axis offset of the first inner shadow.
    @IBInspectable
    var Y1: CGFloat = -2.78 {
        didSet {
            updateInnerShadows()
        }
    }

    /// The blur radius of the first inner shadow.
    @IBInspectable
    var shadowRadius1: CGFloat = 2.78 {
        didSet {
            updateInnerShadows()
        }
    }
    
    // MARK: - Inner Shadow 2 Properties (e.g., Bottom-Right)

    /// Toggles the second inner shadow on or off.
    @IBInspectable
    var hasShadow2: Bool = false {
        didSet {
            updateInnerShadows()
        }
    }

    /// The color of the second inner shadow.
    @IBInspectable
    var shadowColor2: UIColor = UIColor.white {
        didSet {
            updateInnerShadows()
        }
    }

    /// The opacity of the second inner shadow (0.0 to 1.0).
    @IBInspectable
    var opacity2: Float = 0.25 {
        didSet {
            updateInnerShadows()
        }
    }
    
    /// The X-axis offset of the second inner shadow.
    @IBInspectable
    var X2: CGFloat = 2.78 {
        didSet {
            updateInnerShadows()
        }
    }
    
    /// The Y-axis offset of the second inner shadow.
    @IBInspectable
    var Y2: CGFloat = 2.78 {
        didSet {
            updateInnerShadows()
        }
    }

    /// The blur radius of the second inner shadow.
    @IBInspectable
    var shadowRadius2: CGFloat = 2.78 {
        didSet {
            updateInnerShadows()
        }
    }

    // MARK: - Initialization & Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// Ensures the gradient and inner shadows are redrawn if the button's size changes.
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = self.bounds
        updateInnerShadows()
    }
    
    private func setup() {
        gradientLayer.frame = self.bounds
        layer.insertSublayer(gradientLayer, at: 0)
        updateGradient()
    }

    // MARK: - Private Methods

    private func updateGradient() {
        gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
        if isHorizontalGradient {
            gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        } else {
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        }
        layer.masksToBounds = true
    }
    
    private func updateInnerShadows() {
        // Remove existing shadows first
        removeInnerShadow(withName: DesignableButton.innerShadow1LayerName)
        removeInnerShadow(withName: DesignableButton.innerShadow2LayerName)
        
        // Apply shadows if they are enabled
        if hasShadow1 {
            let offset = CGSize(width: X1, height: Y1)
            applyInnerShadow(
                name: DesignableButton.innerShadow1LayerName,
                color: shadowColor1,
                opacity: opacity1,
                offset: offset,
                radius: shadowRadius1
            )
        }
        
        if hasShadow2 {
            let offset = CGSize(width: X2, height: Y2)
            applyInnerShadow(
                name: DesignableButton.innerShadow2LayerName,
                color: shadowColor2,
                opacity: opacity2,
                offset: offset,
                radius: shadowRadius2
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
        
        let path = UIBezierPath(rect: bounds.insetBy(dx: -radius * 2, dy: -radius * 2))
        let innerPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius)
        path.append(innerPath)
        path.usesEvenOddFillRule = true

        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd
        
        innerShadowLayer.mask = maskLayer
        
        layer.masksToBounds = true
        
        layer.addSublayer(innerShadowLayer)
    }

    private func removeInnerShadow(withName name: String) {
        layer.sublayers?.filter({ $0.name == name }).forEach({ $0.removeFromSuperlayer() })
    }
}
