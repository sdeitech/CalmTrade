//
//  PolarBundleViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 10/12/25.
//


import Foundation
import UIKit

final class PolarBundleViewModel {

    private let api = APIService()
    
    // OUTPUT BINDINGS
    var onProductsLoaded: (([PolarProduct]) -> Void)?
    var onError: ((String) -> Void)?
    var onCheckoutCreated: ((String) -> Void)? // checkoutUrl

    private(set) var products: [PolarProduct] = []
    private(set) var selectedProductId: String?

    // MARK: - Fetch products
    func fetchProducts() {
        api.startService(with: .GET,
                         path: "pro/products",
                         parameters: nil,
                         files: nil,
                         modelType: ProductsResponse.self) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                switch result {
                case .Success(let response):
                    guard let items = response?.data?.products else {
                        self.onError?("No products found.")
                        return
                    }
                    self.products = items
                    self.onProductsLoaded?(items)

                case .Error(let msg):
                    self.onError?(msg)
                }
            }
        }
    }

    // MARK: - Select Bundle
    func select(productId: String) {
        selectedProductId = productId
    }

    // MARK: - Checkout
    func startCheckout() {
        guard let id = selectedProductId else {
            onError?("Select a bundle first.")
            return
        }

        let params: [String: Any] = [
            "productIds": [id]
        ]

        api.startService(with: .POST,
                         path: "checkout/create-session",
                         parameters: params,
                         files: nil,
                         modelType: CheckoutResponse.self) { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                switch result {
                case .Success(let r):
                    guard let url = r?.data?.checkoutUrl else {
                        self.onError?("Could not get checkout URL.")
                        return
                    }
                    self.onCheckoutCreated?(url)

                case .Error(let msg):
                    self.onError?(msg)
                }
            }
        }
    }
}
