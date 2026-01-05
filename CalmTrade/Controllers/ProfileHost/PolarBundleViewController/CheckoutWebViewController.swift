//
//  CheckoutWebViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 10/12/25.
//


import UIKit
import WebKit

final class CheckoutWebViewController: UIViewController, WKNavigationDelegate {

    private var webView: WKWebView!
    var checkoutURL: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        webView = WKWebView(frame: view.bounds)
        webView.navigationDelegate = self
        view.addSubview(webView)

        if let url = URL(string: checkoutURL) {
            webView.load(URLRequest(url: url))
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        let urlString = navigationAction.request.url?.absoluteString ?? ""
        print("🔗 OPENED URL →", urlString)

        if urlString.contains("success") {
            let success = UIStoryboard(name: Constants.Storyboard.ProfileHost, bundle: nil).instantiateViewController(withIdentifier: "OrderSuccessfullViewController") as! OrderSuccessfullViewController
            navigationController?.pushViewController(success)
        }

        decisionHandler(.allow)
    }
}
