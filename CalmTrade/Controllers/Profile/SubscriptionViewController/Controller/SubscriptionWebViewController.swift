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
    
    private let vm = SubscriptionViewModel()

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

        guard let urlString = navigationAction.request.url?.absoluteString else {
            decisionHandler(.allow)
            return
        }

        if urlString.contains(successURL) {

            decisionHandler(.cancel)

//            vm.verifyPayment { [weak self] success in
//                guard let self = self else { return }
//
//                if success {
                    self.vm.fetchCurrentSubscription()
                    self.navigationController?.popViewController(animated: true)
//                } else {
//                    let alert = UIAlertController(
//                        title: "Verification Failed",
//                        message: "We couldn't verify your payment. Please contact support.",
//                        preferredStyle: .alert
//                    )
//                    alert.addAction(UIAlertAction(title: "OK", style: .default))
//                    self.present(alert, animated: true)
//                }
//            }

            return
        }

        decisionHandler(.allow)
    }
}

