//
//  SessionLogoutManager.swift
//  CalmTrade
//
//  Created by Anas Parekh on 09/02/26.
//

import Foundation
import UIKit

final class SessionLogoutManager {

    static let shared = SessionLogoutManager()
    private var isLoggingOut = false

    private init() {}

    func logout(reason: Any?) {
        guard !isLoggingOut else { return }
        isLoggingOut = true

        DispatchQueue.main.async {
            self.showAlertAndLogout()
        }
    }

    private func showAlertAndLogout() {
        guard let topVC = UIApplication.shared.topMostViewController else {
            forceLogout()
            return
        }

        let alert = UIAlertController(
            title: "Session Expired",
            message: "Your session has expired. Please log in again.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.forceLogout()
        })

        topVC.present(alert, animated: true)
    }

    private func forceLogout() {
        UserDefaults.standard.removeObject(forKey: "accessToken")
        SocketClient.shared.disconnect()

        let loginVC = UIStoryboard(
            name: Constants.Storyboard.Main,
            bundle: nil
        ).instantiateViewController(withIdentifier: "LoginViewController")

        let nav = UINavigationController(rootViewController: loginVC)
        UIApplication.shared.setRootViewController(nav)

        isLoggingOut = false
    }
}

extension UIApplication {

    var topMostViewController: UIViewController? {
        guard let root = connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else { return nil }

        return top(from: root)
    }

    private func top(from vc: UIViewController) -> UIViewController {
        if let nav = vc as? UINavigationController {
            return top(from: nav.visibleViewController!)
        }
        if let tab = vc as? UITabBarController {
            return top(from: tab.selectedViewController!)
        }
        if let presented = vc.presentedViewController {
            return top(from: presented)
        }
        return vc
    }
    
    func setRootViewController(
        _ viewController: UIViewController,
        animated: Bool = true
    ) {
        guard let window = (UIApplication.shared.delegate as? AppDelegate)?.window else {
            return
        }
        
        if animated {
            UIView.transition(
                with: window,
                duration: 0.3,
                options: .transitionCrossDissolve,
                animations: {
                    window.rootViewController = viewController
                },
                completion: nil
            )
        } else {
            window.rootViewController = viewController
        }
        
        window.makeKeyAndVisible()
    }
}
