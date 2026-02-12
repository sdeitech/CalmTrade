//
//  UserProfileDTO.swift
//  CalmTrade
//
//  Created by Anas Parekh on 29/10/25.
//

import Foundation

// MARK: - API Envelope
public struct ApiEnvelope<T: Decodable>: Decodable {
    public let success: Bool
    public let status: Int?
    public let message: String?
    public let data: T?
}

// MARK: - Server DTO (matches your Get Profile JSON)
public struct UserProfileDTO: Decodable {

    // MARK: - Core identity
    public let id: String
    public let displayName: String?
    public let email: String?
    public let photoURL: String?
    public let accountId: String?
    public let twoFactorEnabled: Bool?

    // MARK: - Dates (ISO8601 strings)
    public let createdAt: String?
    public let lastLoginAt: String?

    // MARK: - Subscription / Features (NEW)
    public let subscription: SubscriptionDTO?
    public let features: [String: FeatureDTO]?

    // MARK: - Future compatibility (not from API)
    public let birthday: Date? = nil
    public let heightCm: Double? = nil
    public let weightKg: Double? = nil

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case displayName = "name"
        case email
        case photoURL = "photos"
        case createdAt
        case lastLoginAt
        case accountId
        case twoFactorEnabled
        case subscription
        case features
    }
}

// MARK: - Device snapshot (Polar 360)
public struct Polar360Snapshot {
    public var ageYears: Int?
    public var biologicalSex: String?
    public var restingHR: Int?
    public var maxHR: Int?
    public var heightCm: Double?
    public var weightKg: Double?

    public static let empty = Polar360Snapshot(
        ageYears: nil, biologicalSex: nil, restingHR: nil,
        maxHR: nil, heightCm: nil, weightKg: nil
    )
}

// MARK: - UI Model
public struct AccountDetailsUI {
    public let displayName: String
    public let email: String
    public let ageText: String
    public let sexText: String
    public let rhrText: String
    public let maxHRText: String
    public let userId: String
    public let createdOn: String
    public let lastSignIn: String
    public let heightText: String
    public let weightText: String
}
