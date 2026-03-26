//
//  DeepLinkRouter.swift
//  CalmTrade
//
//  Created by Anas Parekh on 30/09/25.
//

import UIKit

final class DeepLinkRouter {
    static let shared = DeepLinkRouter()
    private init() {}

    // MARK: - Entry
    func handle(url: URL) {
        let scheme = url.scheme?.lowercased()
        let host   = url.host?.lowercased()
        
        // Custom scheme (still supported if you want)
        if scheme == "calmtrade", host == "verify-email" {
            let token = extractToken(from: url)              // query ?token=... or /<token>
            let email = url.queryItem("email")
            routeToEmailVerification(token: token, email: email)
            return
        }
        
        if url.scheme?.lowercased() == "https",
           (url.host?.lowercased() == "api.getcalmtrade.com" || url.host?.lowercased() == "getcalmtrade.com"),
           url.path.lowercased().hasPrefix("/verify-email") {
            
            let token = url.queryItem("token") ?? (url.lastPathComponent.lowercased() == "verify-email" ? nil : url.lastPathComponent)
            let email = url.queryItem("email")
            routeToEmailVerification(token: token, email: email)
        }
    }

    // MARK: - Custom Scheme: CalmTrade://verify-email[/<token>][?token=...&email=...]
    private func handleCustomScheme(_ url: URL) {
        guard url.host?.lowercased() == "verify-email" else { return }
        let token = extractToken(from: url)
        let email = url.queryItem("email")
        routeToEmailVerification(token: token, email: email)
    }

    // MARK: - Universal Link: https://<host>/verify-email?token=...&email=...
    private func handleUniversalLink(_ url: URL) {
        // Accept any host; restrict if you want to: ["staging.calmtrade.io","app.calmtrade.io"].contains(url.host)
        guard url.path.lowercased() == "/verify-email" else {
            // Also support path variant with token segment: /verify-email/<token>
            let comps = url.pathComponents.map { $0.lowercased() }
            if comps.count >= 3, comps[1] == "verify-email" {
                let tokenSeg = url.lastPathComponent
                let email = url.queryItem("email")
                routeToEmailVerification(token: tokenSeg.isEmpty ? nil : tokenSeg, email: email)
            }
            return
        }
        let token = url.queryItem("token")
        let email = url.queryItem("email")
        routeToEmailVerification(token: token, email: email)
    }

    // MARK: - Token extraction helpers
    private func extractToken(from url: URL) -> String? {
        // Prefer ?token=...
        if let token = url.queryItem("token"), !token.isEmpty { return token }

        // Else use last path component CalmTrade://verify-email/<token>
        let last = url.lastPathComponent
        return last.isEmpty ? nil : last.removingPercentEncoding
    }

    // MARK: - Navigation
    private func routeToEmailVerification(token: String?, email: String?) {
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }),
                  let root = window.rootViewController else { return }
            
            let nav = (root as? UINavigationController) ?? root.navigationController
            
            if let top = nav?.topViewController as? EmailVerificationViewController {
                top.passedEmail = top.passedEmail ?? email
                top.viewModel.verifyViaDeepLink(token: token, email: top.passedEmail)
                return
            }
            
            let vc = UIStoryboard(name: "Main", bundle: nil)
                .instantiateViewController(withIdentifier: "EmailVerificationViewController") as! EmailVerificationViewController
            vc.passedEmail = email
            nav?.pushViewController(vc, animated: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                vc.viewModel.verifyViaDeepLink(token: token, email: vc.passedEmail)
            }
        }
    }

    // MARK: - Utils
    private func topMostViewController(base: UIViewController? = UIApplication.shared.keyWindowInConnectedScenes?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topMostViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topMostViewController(base: presented)
        }
        return base
    }
}

// MARK: - URL helpers
private extension URL {
    func queryItem(_ name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?
            .value?
            .removingPercentEncoding
    }
}

// MARK: - UIWindow helper (supports multi-scene)
private extension UIApplication {
    var keyWindowInConnectedScenes: UIWindow? {
        return self.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
    }
}
