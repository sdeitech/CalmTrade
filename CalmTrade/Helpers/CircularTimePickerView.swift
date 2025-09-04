//
//  CircularTimePickerView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/09/25.
//


import UIKit

@IBDesignable
class CircularTimePickerView: UIView {

    // MARK: - Public Properties
    var onTimeChanged: ((_ startTime: Date, _ endTime: Date) -> Void)?
    
    var startTime: Date = Calendar.current.date(bySettingHour: 22, minute: 30, second: 0, of: Date())! {
        didSet { updateUI() }
    }
    var endTime: Date = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: Date())!)! {
        didSet { updateUI() }
    }
    
    // MARK: - Private UI
    private let trackLayer = CAShapeLayer()
    private let selectionLayer = CAShapeLayer()
    private let startHandle = UIView() // Bed Icon (Sleep Start)
    private let endHandle = UIView()   // Alarm Icon (Wake Up)
    private var activeHandle: UIView?

    // MARK: - Init & Layout
    override init(frame: CGRect) { super.init(frame: frame); setupView() }
    required init?(coder: NSCoder) { super.init(coder: coder); setupView() }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let radius = min(bounds.width, bounds.height) / 2 - 20
        
        trackLayer.path = UIBezierPath(arcCenter: center, radius: radius, startAngle: -(.pi / 2), endAngle: .pi * 1.5, clockwise: true).cgPath
        selectionLayer.frame = bounds
        
        updatePathAndHandles()
    }
    
    private func setupView() {
        backgroundColor = .clear
        
        layer.addSublayer(trackLayer)
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.darkGray.cgColor
        trackLayer.lineWidth = 15
        
        layer.addSublayer(selectionLayer)
        selectionLayer.fillColor = UIColor.clear.cgColor
        selectionLayer.strokeColor = UIColor.systemBlue.cgColor
        selectionLayer.lineWidth = 20
        selectionLayer.lineCap = .round
        
        // **THE CHANGE IS HERE**: This creates the dashed line effect.
        // The pattern is [dash length, gap length].
        selectionLayer.lineDashPattern = [20, 8]
        
        setupHandle(startHandle, imageName: "bed 1")
        setupHandle(endHandle, imageName: "alarm")
        
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))
    }
    
    private func setupHandle(_ handle: UIView, imageName: String) {
        handle.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        handle.backgroundColor = .clear
        
        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        handle.addSubview(imageView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: handle.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: handle.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: handle.widthAnchor, multiplier: 0.6),
            imageView.heightAnchor.constraint(equalTo: handle.heightAnchor, multiplier: 0.6)
        ])
        
        addSubview(handle)
    }
    
    // MARK: - Update & Drawing
    private func updateUI() {
        setNeedsLayout()
        onTimeChanged?(startTime, endTime)
    }
    
    private func updatePathAndHandles() {
        let startAngle = angle(for: startTime)
        let endAngle = angle(for: endTime)
        
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let radius = min(bounds.width, bounds.height) / 2 - 20
        
        let selectionPath = UIBezierPath()
        selectionPath.addArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        selectionLayer.path = selectionPath.cgPath

        positionHandle(startHandle, at: startAngle)
        positionHandle(endHandle, at: endAngle)
    }

    private func positionHandle(_ handle: UIView, at angle: CGFloat) {
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let radius = min(bounds.width, bounds.height) / 2 - 20
        handle.center = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }

    // MARK: - Gesture Handling
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        if gesture.state == .began {
            let startDist = distance(from: startHandle.center, to: location)
            let endDist = distance(from: endHandle.center, to: location)
            activeHandle = startDist < endDist ? startHandle : endHandle
        }
        
        if gesture.state == .changed, let activeHandle = activeHandle {
            let angle = angle(from: location)
            let newDate = date(for: angle, referenceDate: activeHandle == startHandle ? startTime : endTime)
            
            if activeHandle == startHandle {
                startTime = newDate
            } else {
                endTime = newDate
            }
        }
        
        if gesture.state == .ended || gesture.state == .cancelled {
            activeHandle = nil
            if endTime <= startTime {
                endTime = Calendar.current.date(byAdding: .day, value: 1, to: endTime)!
            }
        }
    }
    
    // MARK: - Angle/Date Conversion (24-Hour Logic)
    private func angle(for date: Date) -> CGFloat {
        let totalMinutes = CGFloat(Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date))
        return (totalMinutes / 1440.0) * 2 * .pi - (.pi / 2)
    }
    
    private func angle(from point: CGPoint) -> CGFloat {
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        return atan2(point.y - center.y, point.x - center.x)
    }
    
    private func date(for angle: CGFloat, referenceDate: Date) -> Date {
        let correctedAngle = angle + .pi / 2
        var percentage = correctedAngle / (2 * .pi)
        if percentage < 0 { percentage += 1 }
        
        let totalMinutes = Int(round(percentage * 1440.0))
        // Handle the "hour 24" case by treating it as hour 0
        let hour = totalMinutes / 60 == 24 ? 0 : totalMinutes / 60
        let minute = totalMinutes % 60
        
        // Safely create the date. This will not crash.
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: referenceDate) ?? referenceDate
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        return sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
    }
}
