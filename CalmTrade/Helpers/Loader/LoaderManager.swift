//
//  LoaderManager.swift
//  CalmTrade
//
//  Created by Anas Parekh on 02/03/26.
//


import UIKit

final class LoaderManager {

    static let shared = LoaderManager()

    private var overlay: LoaderOverlay?
    private let lock = NSLock()

    private init() {}

    // MARK: - Public

    func show() {
        DispatchQueue.main.async {
            self.lock.lock()
            defer { self.lock.unlock() }

            guard self.overlay == nil else { return }

            guard let window = Self.activeWindow else { return }

            let overlay = LoaderOverlay(frame: window.bounds)
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            window.addSubview(overlay)
            self.overlay = overlay
        }
    }

    func hide() {
        DispatchQueue.main.async {
            self.lock.lock()
            defer { self.lock.unlock() }

            self.overlay?.removeFromSuperview()
            self.overlay = nil
        }
    }
}

private extension LoaderManager {

    static var activeWindow: UIWindow? {
        UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
