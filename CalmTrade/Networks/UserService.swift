//
//  LoginAPIManager.swift
//  iOSArchitecture
//
//  Created by Amit on 23/02/18.
//  Copyright © 2018 smartData. All rights reserved.
//

import Foundation
import FirebaseAuth

// MARK: - Service Protocol

protocol UserServiceProtocol {
    func login(email: String, password: String, completion: @escaping (Result<AuthResponse?>) -> Void)
    func me(completion: @escaping (Result<User?>) -> Void)

    func googleAuth(idToken: String, completion: @escaping (Result<AuthResponse?>) -> Void)
    func appleAuth(identityToken: String, authorizationCode: String, givenName: String, familyName: String, completion: @escaping (Result<AuthResponse?>) -> Void)
    func facebookAuth(accessToken: String, name: String, email: String, userId: String, imageUrl: String, completion: @escaping (Result<AuthResponse?>) -> Void)

    func forgotPassword(email: String, completion: @escaping (Result<BaseMessage?>) -> Void)
    func verifyOTP(email: String, otp: String, completion: @escaping (Result<VerifyOtpResponse?>) -> Void)
    func resetPassword(email: String, otp: String, newPassword: String, completion: @escaping (Result<ResetPasswordResponse?>) -> Void)

    /// Get Profile (Bearer) — **uses your project's custom `Result<T?>`**
    func getProfile(accessToken: String, completion: @escaping (Result<ApiEnvelope<UserProfileDTO>?>) -> Void)
}

// MARK: - Concrete Service

final class UserService: APIService, UserServiceProtocol {

    func login(email: String, password: String, completion: @escaping (Result<AuthResponse?>) -> Void) {
        let param = [Keys.email: email, Keys.password: password,"firebaseToken":UserDefaults.standard.string(forKey: "fcmToken") ?? "","deviceType":"mobile"]
        startService(with: .POST,
                     path: Endpoints.Auth.login.rawValue,
                     parameters: param,
                     files: [],
                     modelType: AuthResponse.self,
                     completion: completion)
    }

    func me(completion: @escaping (Result<User?>) -> Void) {
        startService(with: .GET,
                     path: Endpoints.Users.me.rawValue,
                     parameters: nil,
                     files: [],
                     modelType: User.self,
                     completion: completion)
    }

    func googleAuth(idToken: String, completion: @escaping (Result<AuthResponse?>) -> Void) {
        startService(with: .POST,
                     path: Endpoints.Auth.googleAuth.rawValue,
                     parameters: ["idToken": idToken,"firebaseToken":UserDefaults.standard.string(forKey: "fcmToken") ?? "","deviceType":"mobile"],
                     files: [],
                     modelType: AuthResponse.self,
                     completion: completion)
    }

    func appleAuth(identityToken: String,
                   authorizationCode: String,
                   givenName: String,
                   familyName: String,
                   completion: @escaping (Result<AuthResponse?>) -> Void) {
        let params: [String: Any] = [
            "identityToken": identityToken,
            "authorizationCode": authorizationCode,
            "givenName": givenName,
            "familyName": familyName,
            "firebaseToken":UserDefaults.standard.string(forKey: "fcmToken") ?? "",
            "deviceType":"mobile"
        ]
        startService(with: .POST,
                     path: Endpoints.Auth.appleAuth.rawValue,
                     parameters: params,
                     files: [],
                     modelType: AuthResponse.self,
                     completion: completion)
    }

    func facebookAuth(accessToken: String,
                      name: String,
                      email: String,
                      userId: String,
                      imageUrl: String,
                      completion: @escaping (Result<AuthResponse?>) -> Void) {
        let params = [
            "token": accessToken,
            "name": name,
            "email": email,
            "userId": userId,
            "imageUrl": imageUrl,
            "firebaseToken":UserDefaults.standard.string(forKey: "fcmToken") ?? "",
            "deviceType":"mobile"
        ]
        startService(with: .POST,
                     path: Endpoints.Auth.facebookAuth.rawValue,
                     parameters: params,
                     files: [],
                     modelType: AuthResponse.self,
                     completion: completion)
    }

    func forgotPassword(email: String, completion: @escaping (Result<BaseMessage?>) -> Void) {
        let params = [Keys.email: email]
        startService(with: .POST,
                     path: Endpoints.Auth.forgotPassword.rawValue,
                     parameters: params,
                     files: [],
                     modelType: BaseMessage.self,
                     completion: completion)
    }

    func verifyOTP(email: String, otp: String, completion: @escaping (Result<VerifyOtpResponse?>) -> Void) {
        let params = [Keys.email: email, "otp": otp,"firebaseToken":UserDefaults.standard.string(forKey: "fcmToken") ?? "","deviceType":"mobile"]
        startService(with: .POST,
                     path: Endpoints.Auth.verifyOTP.rawValue,
                     parameters: params,
                     files: [],
                     modelType: VerifyOtpResponse.self,
                     completion: completion)
    }

    func resetPassword(email: String,
                       otp: String,
                       newPassword: String,
                       completion: @escaping (Result<ResetPasswordResponse?>) -> Void) {
        let params: [String: Any] = [
            "email": email,
            "otp": otp,
            "newPassword": newPassword
        ]
        startService(with: .POST,
                     path: Endpoints.Auth.resetPassword.rawValue,
                     parameters: params,
                     files: [],
                     modelType: ResetPasswordResponse.self,
                     completion: completion)
    }

    // MARK: - Get Profile (Bearer) — custom Result<T?>
    //
    // If APIService already injects Authorization headers globally, `accessToken` can be ignored.
    // Otherwise, extend APIService to accept custom headers and attach "Authorization: Bearer \(accessToken)".
    //
    func getProfile(accessToken: String,
                    completion: @escaping (Result<ApiEnvelope<UserProfileDTO>?>) -> Void) {
        startService(with: .GET,
                     // Adjust if your backend uses a different route (e.g., Endpoints.Users.me)
                     path: Endpoints.Auth.getProfile.rawValue,
                     parameters: nil,
                     files: [],
                     modelType: ApiEnvelope<UserProfileDTO>.self,
                     completion: completion)
    }
}
