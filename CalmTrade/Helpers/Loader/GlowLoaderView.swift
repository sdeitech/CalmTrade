//
//  GlowLoaderView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 02/03/26.
//


import UIKit
import Foundation

final class GlowLoaderView: UIView {

    private let replicator = CAReplicatorLayer()
    private let dotLayer = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear

        let dotSize: CGFloat = 10
        let radius: CGFloat = 40

        replicator.frame = bounds
        replicator.instanceCount = 16
        replicator.instanceDelay = 0.08
        replicator.instanceTransform = CATransform3DMakeRotation(
            CGFloat.pi * 2 / 16,
            0, 0, 1
        )

        dotLayer.frame = CGRect(
            x: bounds.midX - dotSize / 2,
            y: bounds.midY - radius,
            width: dotSize,
            height: dotSize
        )
        dotLayer.cornerRadius = dotSize / 2
        dotLayer.backgroundColor = UIColor.systemBlue.cgColor

        // Glow
        dotLayer.shadowColor = UIColor.systemBlue.cgColor
        dotLayer.shadowRadius = 10
        dotLayer.shadowOpacity = 0.9
        dotLayer.shadowOffset = .zero

        replicator.addSublayer(dotLayer)
        layer.addSublayer(replicator)

        animate()
    }

    private func animate() {
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.4
        scale.toValue = 1.0
        scale.duration = 1.2
        scale.repeatCount = .infinity
        scale.autoreverses = true

        dotLayer.add(scale, forKey: "scale")
    }
}

final class LoaderOverlay: UIView {

    private let blur = UIView()//UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let loader = GlowLoaderView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        blur.backgroundColor = .clear
        blur.frame = bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blur)

        loader.translatesAutoresizingMaskIntoConstraints = false
        addSubview(loader)

        NSLayoutConstraint.activate([
            loader.centerXAnchor.constraint(equalTo: centerXAnchor),
            loader.centerYAnchor.constraint(equalTo: centerYAnchor),
            loader.widthAnchor.constraint(equalToConstant: 0),
            loader.heightAnchor.constraint(equalToConstant: 0)
        ])
    }
}
