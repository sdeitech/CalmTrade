//
//  BrokerWebViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 11/12/25.
//


import UIKit
import WebKit
import KRProgressHUD

final class BrokerWebViewController: UIViewController, WKNavigationDelegate {

    var initialURL: String = ""
    private var webView: WKWebView!

    // Injected by parent controller
    var viewModel: ImportTradesViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()

        webView = WKWebView(frame: .zero)
        webView.navigationDelegate = self
        view = webView

        if let url = URL(string: initialURL) {
            webView.load(URLRequest(url: url))
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let urlString = url.absoluteString
        print("🔗 Redirected to: \(urlString)")

        // Detect success callback
        if urlString.contains("connection-complete") {
            handleBrokerSuccess(url: url)
        }

        decisionHandler(.allow)
    }

    private func handleBrokerSuccess(url: URL) {
        KRProgressHUD.show()
        viewModel?.callBrokerCallbackAndSync() { [weak self] ok in
            guard let self else { return }
            KRProgressHUD.dismiss()

            if ok {
                self.navigationController?.popViewController()
            } else {
                print("❌ Callback or sync failed")
            }
        }
    }
}

