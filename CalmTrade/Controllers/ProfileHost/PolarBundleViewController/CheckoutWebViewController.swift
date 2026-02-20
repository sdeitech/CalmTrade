//
//  CheckoutWebViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 10/12/25.
//


import UIKit
import WebKit
import KRProgressHUD

final class CheckoutWebViewController: UIViewController, WKNavigationDelegate {

    private var webView: WKWebView!
    var checkoutURL: String = ""
    var bundleVM: PolarBundleViewModel?

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

            decisionHandler(.cancel)

            KRProgressHUD.show()

            bundleVM?.syncPayment { [weak self] success in
                guard let self = self else { return }

                KRProgressHUD.dismiss()

                if success {

                    let successVC = UIStoryboard(
                        name: Constants.Storyboard.ProfileHost,
                        bundle: nil
                    ).instantiateViewController(
                        withIdentifier: "OrderSuccessfullViewController"
                    ) as! OrderSuccessfullViewController

                    self.navigationController?.pushViewController(successVC, animated: true)

                } else {

                    let alert = UIAlertController(
                        title: "Verification Failed",
                        message: "We couldn't verify your payment. Please contact support.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }

            return
        }

        decisionHandler(.allow)
    }
}
