//
//  PolarBundleViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 10/12/25.
//


import UIKit
import WebKit
import KRProgressHUD

final class PolarBundleViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var viewH10: UIView!
    @IBOutlet weak var view360: UIView!

    @IBOutlet weak var imgH10: UIImageView!
    @IBOutlet weak var lblH10Name: UILabel!
    @IBOutlet weak var lblH10Desc: UILabel!
    @IBOutlet weak var lblH10Price: UILabel!
    @IBOutlet weak var lblH10Months: UILabel!

    @IBOutlet weak var img360: UIImageView!
    @IBOutlet weak var lbl360Name: UILabel!
    @IBOutlet weak var lbl360Desc: UILabel!
    @IBOutlet weak var lbl360Price: UILabel!
    @IBOutlet weak var lbl360Months: UILabel!

    @IBOutlet weak var btnContinue: UIButton!

    private let vm = PolarBundleViewModel()

    private var h10Product: PolarProduct?
    private var p360Product: PolarProduct?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindVM()
        vm.fetchProducts()
    }

    private func setupUI() {
        viewH10.borderWidth = 0
        view360.borderWidth = 0
    }

    private func bindVM() {
        vm.onProductsLoaded = { [weak self] items in
            guard let self else { return }
            self.configureBundles(items)
        }

        vm.onError = { [weak self] msg in
            guard let s = self else { return }
            LoaderManager.shared.hide()
            s.showAlert(message: msg)
        }

        vm.onCheckoutCreated = { [weak self] checkoutURL in
            guard let self else { return }
            LoaderManager.shared.hide()
            self.openCheckout(url: checkoutURL)
        }
    }
    
    private func openCheckout(url: String) {
        let vc = CheckoutWebViewController()
        vc.checkoutURL = url
        vc.bundleVM = vm
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Set UI From API
    private func configureBundles(_ products: [PolarProduct]) {

        for p in products {
            if p.productId == "polar-h10" {
                h10Product = p
                lblH10Name.text = p.name
                lblH10Desc.text = p.description
                lblH10Price.text = "$\(Double(p.price) / 100)"
                lblH10Months.text = "(\(p.subscriptionMonths) months Elite)"
            }
            if p.productId == "polar-360" {
                p360Product = p
                lbl360Name.text = p.name
                lbl360Desc.text = p.description
                lbl360Price.text = "$\(Double(p.price) / 100)"
                lbl360Months.text = "(\(p.subscriptionMonths) months Elite)"
            }
        }
    }

    // MARK: - Actions
    @IBAction func tapH10(_ sender: Any) {
        guard let p = h10Product else { return }
        vm.select(productId: p.productId)
        updateSelectionUI(selected: .h10)
    }

    @IBAction func tap360(_ sender: Any) {
        guard let p = p360Product else { return }
        vm.select(productId: p.productId)
        updateSelectionUI(selected: .p360)
    }

    private enum BundleSelected { case h10, p360 }

    private func updateSelectionUI(selected: BundleSelected) {
        let blue = UIColor(hex: "008AFF")
        let gray = UIColor(hex: "2D2D2D")

        switch selected {

        case .h10:
            viewH10.borderWidth = 2
            view360.borderWidth = 0

            lblH10Price.textColor = blue
            lbl360Price.textColor = gray

        case .p360:
            viewH10.borderWidth = 0
            view360.borderWidth = 2

            lblH10Price.textColor = gray
            lbl360Price.textColor = blue
        }
    }

    @IBAction func btnContinueTapped(_ sender: Any) {
        LoaderManager.shared.show()
        vm.startCheckout()
    }
}
