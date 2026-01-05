//
//  SubscriptionWebViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 11/12/25.
//


import UIKit
import WebKit

final class SubscriptionWebViewController: UIViewController, WKNavigationDelegate {

    var checkoutURL: String = ""
    var successURL: String = "https://www.google.com/" // same domain prefix

    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.translatesAutoresizingMaskIntoConstraints = false
        return wv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupWebView()
        loadURL()
    }

    private func setupWebView() {
        view.addSubview(webView)

        // Fullscreen (bounds == view)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadURL() {
        guard let url = URL(string: checkoutURL) else { return }
        webView.load(URLRequest(url: url))
    }

    // Detect redirect
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        if let urlString = navigationAction.request.url?.absoluteString,
           urlString.contains(successURL) {
            navigationController?.popViewController(animated: true)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }
}

