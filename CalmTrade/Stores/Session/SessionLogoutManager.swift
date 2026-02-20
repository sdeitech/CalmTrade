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
    
    private let api: ApiServiceProtocol = APIService()

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
    
    func forceLogout() {

        let params: [String: Any] = [
            "deviceType": "mobile"
        ]

        api.startService(
            with: .POST,
            path: "user/logout",
            parameters: params,
            files: nil,
            modelType: EmptyResponse.self
        ) { _ in
            DispatchQueue.main.async {
                self.performLocalLogout()
            }
        }
    }

    private func performLocalLogout() {

        UserDefaults.standard.removeObject(forKey: "accessToken")
        UserDefaults.standard.removeObject(forKey: "fcmToken")

        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.clearFCMToken()
        }

        SocketClient.shared.disconnect()

        let splash = UIStoryboard(
            name: Constants.Storyboard.Main,
            bundle: nil
        ).instantiateViewController(withIdentifier: "SplashViewController")

        let nav = UINavigationController(rootViewController: splash)
        nav.navigationBar.isHidden = true

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
        
        guard
            let windowScene = connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
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
