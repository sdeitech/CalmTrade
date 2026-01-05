//
//  LoginViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/08/25.
//

import Combine
import Foundation

final class LoginViewModel: BaseViewModel {
    @Published var email = ""
    @Published var password = ""
    @Published var error: String?
    @Published var user: User?               // Unified User model

    private let repo: UserRepositoryProtocol
    private let profileService = ProfileService()

    init(repo: UserRepositoryProtocol = UserRepository()) {
        self.repo = repo
    }

    // MARK: - Validation
    func validate() -> String? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPass  = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else { return "Please enter your email." }
        guard isValidEmail(trimmedEmail) else { return "Please enter a valid email address." }
        guard !trimmedPass.isEmpty else { return "Please enter your password." }
        guard trimmedPass.count >= 6 else { return "Password must be at least 6 characters." }
        return nil
    }

    private func isValidEmail(_ s: String) -> Bool {
        let pattern = #"^\S+@\S+\.\S+$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Reusable profile fetcher
    private func finalizeLogin(using token: String, completion: @escaping (Bool, String?) -> Void) {

        profileService.refreshProfile(accessToken: token) { [weak self] dto, err in
            guard let self else { return }

            if let dto = dto {
//                let user = User(from: dto)
                self.user = dto

//                SessionManager.shared.setCurrentUser(user, token: token)
                // Connect socket after session is established
                SocketClient.shared.connect(with: token)
                completion(true, nil)
            } else {
                completion(false, err ?? "Failed to load profile")
            }
        }
    }

    // MARK: - Email/Password login
    func submit(completion: @escaping (_ success: Bool, _ message: String?, _ needsVerification: Bool) -> Void) {

        if let validationError = validate() {
            completion(false, validationError, false)
            return
        }

        isLoading = true
        error = nil

        repo.login(email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                switch result {

                case .Success(let resp):
                    guard let resp else {
                        completion(false, "Empty response", false)
                        return
                    }

                    guard resp.success else {
                        if resp.isVerified == false {
                            completion(false, resp.message, true)
                        } else {
                            completion(false, resp.message, false)
                        }
                        return
                    }

                    guard let token = resp.accessToken, !token.isEmpty else {
                        completion(false, "Missing access token", false)
                        return
                    }
                    
                    self.updateUserToken(token)

                    // Fetch profile + finalize login
                    self.finalizeLogin(using: token) { ok, msg in
                        completion(ok, msg, false)
                    }

                case .Error(let msg):
                    completion(false, msg, false)
                }
            }
        }
    }

    // MARK: - Google Login
    func googleAuth(idToken: String,
                    completion: @escaping (_ success: Bool, _ message: String?, _ isFirstTimeUser: Bool) -> Void) {

        isLoading = true
        error = nil

        repo.googleAuth(idToken: idToken) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                switch result {

                case .Success(let resp):
                    let first = resp?.newAccount ?? false

                    guard let resp, resp.success else {
                        completion(false, resp?.message, first)
                        return
                    }

                    guard let token = resp.accessToken else {
                        completion(false, "Missing access token", first)
                        return
                    }
                    
                    self.updateUserToken(token)

                    // Load profile
                    self.finalizeLogin(using: token) { ok, msg in
                        print("✅ googleAuth calling completion for VM:", ObjectIdentifier(self))
                        completion(ok, msg, first)
                    }

                case .Error(let msg):
                    completion(false, msg, false)
                }
            }
        }
    }

    // MARK: - Apple Login
    func appleAuth(identityToken: String,
                   authorizationCode: String,
                   givenName: String,
                   familyName: String,
                   completion: @escaping (_ success: Bool, _ message: String?, _ isFirstTimeUser: Bool) -> Void) {

        isLoading = true
        error = nil

        repo.appleAuth(identityToken: identityToken,
                       authorizationCode: authorizationCode,
                       givenName: givenName,
                       familyName: familyName) { [weak self] result in

            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                switch result {

                case .Success(let resp):
                    let first = resp?.newAccount ?? false

                    guard let resp, resp.success else {
                        completion(false, resp?.message, first)
                        return
                    }

                    guard let token = resp.accessToken else {
                        completion(false, "Missing access token", first)
                        return
                    }
                    
                    self.updateUserToken(token)

                    // Load profile
                    self.finalizeLogin(using: token) { ok, msg in
                        completion(ok, msg, first)
                    }

                case .Error(let msg):
                    completion(false, msg, false)
                }
            }
        }
    }

    // MARK: - Facebook Login
    func facebookAuth(accessToken: String,
                      name: String,
                      email: String,
                      userId: String,
                      imageUrl: String,
                      completion: @escaping (_ success: Bool, _ message: String?, _ isFirstTimeUser: Bool) -> Void) {

        isLoading = true
        error = nil

        repo.facebookAuth(accessToken: accessToken,
                          name: name,
                          email: email,
                          userId: userId,
                          imageUrl: imageUrl) { [weak self] result in

            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                switch result {

                case .Success(let resp):
                    let first = resp?.newAccount ?? false

                    guard let resp, resp.success else {
                        completion(false, resp?.message, first)
                        return
                    }

                    guard let token = resp.accessToken else {
                        completion(false, "Missing access token", first)
                        return
                    }
                    
                    self.updateUserToken(token)

                    // Load profile
                    self.finalizeLogin(using: token) { ok, msg in
                        completion(ok, msg, first)
                    }

                case .Error(let msg):
                    completion(false, msg, false)
                }
            }
        }
    }
}
