//
//  UserRepository.swift
//  CalmTrade
//
//  Created by Anas Parekh on 22/09/25.
//

import Foundation

// MARK: - Protocol

protocol UserRepositoryProtocol {
    func login(email: String, password: String, completion: @escaping (Result<AuthResponse?>) -> Void)
    func me(completion: @escaping (Result<User?>) -> Void)

    func googleAuth(idToken: String, completion: @escaping (Result<AuthResponse?>) -> Void)
    func appleAuth(identityToken: String, authorizationCode: String, givenName: String, familyName: String, completion: @escaping (Result<AuthResponse?>) -> Void)
    func facebookAuth(accessToken: String, name: String, email: String, userId: String, imageUrl: String, completion: @escaping (Result<AuthResponse?>) -> Void)

    func forgotPassword(email: String, completion: @escaping (Result<BaseMessage?>) -> Void)
    func verifyOTP(email: String, otp: String, completion: @escaping (Result<VerifyOtpResponse?>) -> Void)
    func resetPassword(email: String, otp: String, newPassword: String, completion: @escaping (Result<ResetPasswordResponse?>) -> Void)

    /// Get Profile (Bearer) — matches `UserServiceProtocol.getProfile`
    func fetchProfile(accessToken: String, completion: @escaping (Result<ApiEnvelope<UserProfileDTO>?>) -> Void)
}

// MARK: - Repository

final class UserRepository: UserRepositoryProtocol {
    private let svc: UserServiceProtocol

    init(svc: UserServiceProtocol = UserService()) {
        self.svc = svc
    }

    func login(email: String, password: String, completion: @escaping (Result<AuthResponse?>) -> Void) {
        svc.login(email: email, password: password, completion: completion)
    }

    func me(completion: @escaping (Result<User?>) -> Void) {
        svc.me(completion: completion)
    }

    func googleAuth(idToken: String, completion: @escaping (Result<AuthResponse?>) -> Void) {
        svc.googleAuth(idToken: idToken, completion: completion)
    }

    func appleAuth(identityToken: String, authorizationCode: String, givenName: String, familyName: String, completion: @escaping (Result<AuthResponse?>) -> Void) {
        svc.appleAuth(identityToken: identityToken, authorizationCode: authorizationCode, givenName: givenName, familyName: familyName, completion: completion)
    }

    func facebookAuth(accessToken: String, name: String, email: String, userId: String, imageUrl: String, completion: @escaping (Result<AuthResponse?>) -> Void) {
        svc.facebookAuth(accessToken: accessToken, name: name, email: email, userId: userId, imageUrl: imageUrl, completion: completion)
    }

    func forgotPassword(email: String, completion: @escaping (Result<BaseMessage?>) -> Void) {
        svc.forgotPassword(email: email, completion: completion)
    }

    func verifyOTP(email: String, otp: String, completion: @escaping (Result<VerifyOtpResponse?>) -> Void) {
        svc.verifyOTP(email: email, otp: otp, completion: completion)
    }

    func resetPassword(email: String, otp: String, newPassword: String, completion: @escaping (Result<ResetPasswordResponse?>) -> Void) {
        svc.resetPassword(email: email, otp: otp, newPassword: newPassword, completion: completion)
    }

    func fetchProfile(accessToken: String, completion: @escaping (Result<ApiEnvelope<UserProfileDTO>?>) -> Void) {
        svc.getProfile(accessToken: accessToken, completion: completion)
    }
}

// MARK: - Models used elsewhere

struct User: Codable {
    let id: String
    let displayName: String
    let email: String
    let photoURL: String?
    let createdAt: Date?
    let lastLoginAt: Date?
    let twoFactorEnabled: Bool?

    var heightCm: Double?
    var weightKg: Double?
    var age: Int?
    var sex: String?
    var accountId: String?

    init(from dto: UserProfileDTO) {
        self.id = dto.id
        self.displayName = dto.displayName ?? ""
        self.email = dto.email ?? ""
        self.photoURL = dto.photoURL
        self.createdAt = User.parse(dto.createdAt)
        self.lastLoginAt = User.parse(dto.lastLoginAt)
        self.accountId = dto.accountId ?? ""
        self.twoFactorEnabled = dto.twoFactorEnabled
    }

    private static func parse(_ iso: String?) -> Date? {
        guard let s = iso else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }
}

struct BaseMessage: Decodable {
    let message: String?
}

struct ResetPasswordResponse: Decodable {
    let success: Bool
    let message: String?
}

struct VerifyOtpResponse: Decodable {
    let success: Bool
    let message: String?
    let token: String?
}
