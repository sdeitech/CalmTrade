//
//  ProductsResponse.swift
//  CalmTrade
//
//  Created by Anas Parekh on 10/12/25.
//


struct ProductsResponse: Decodable {
    let status: Int?
    let success: Bool?
    let message: String?
    let data: ProductData?
}

struct ProductData: Decodable {
    let products: [PolarProduct]
}

struct PolarProduct: Decodable {
    let _id: String
    let productId: String
    let name: String
    let description: String
    let price: Int
    let subscriptionMonths: Int
    let image: String
}
