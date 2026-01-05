//
//  SocialLoginHandler.swift
//  CalmTrade
//
//  Firebase-free social sign-in façade for Google, Facebook, and Apple.
//  Safe for newer SDKs (GoogleSignIn, FBSDK) and avoids version-specific calls.
//

import UIKit
import GoogleSignIn
import FBSDKLoginKit
import FBSDKCoreKit
import AuthenticationServices
import CryptoKit

// MARK: - Lightweight Auth Credential

public struct AuthCredential {
    public enum Provider: String { case google, facebook, apple }

    public let provider: Provider
    public let userID: String?
    public let email: String?
    public let fullName: String?
    public let givenName: String?
    public let familyName: String?
    public let accessToken: String?
    public let idToken: String?
    public let authorizationCode: String? // Google serverAuthCode or Apple authorizationCode
    public let avatarURL: String?
    public let raw: Any?
}

// MARK: - Internal Errors

private enum SocialAuthError: LocalizedError {
    case cancelled
    case configuration(String)
    case sdk(String)
    case noCredentials(String)
    case internalState(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Sign-in was cancelled by the user."
        case .configuration(let m): return "Configuration error: \(m)"
        case .sdk(let m): return "Provider SDK error: \(m)"
        case .noCredentials(let m): return "Missing credentials: \(m)"
        case .internalState(let m): return "Internal state error: \(m)"
        }
    }
}

// MARK: - Handler

final class SocialLoginHandler: NSObject {

    // Optional override if you don’t want to keep the client ID in Info.plist.
    static var googleClientIDOverride: String?

    private weak var presentingVC: UIViewController?
    private var appleSignInCompletion: ((Swift.Result<AuthCredential, Error>) -> Void)?
    private var authorizationController: ASAuthorizationController?

    private(set) var lastGoogleIDToken: String?

    // MARK: Google

    func signInWithGoogle(
        presentingVC: UIViewController,
        completion: @escaping (Swift.Result<AuthCredential, Error>) -> Void
    ) {
        // Prefer override, else Info.plist keys (both supported).
        guard let clientID =
                Self.googleClientIDOverride ??
                (Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String) ??
                (Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String)
        else {
            completion(.failure(SocialAuthError.configuration("Missing Google Client ID. Add 'GIDClientID' to Info.plist or set SocialLoginHandler.googleClientIDOverride.")))
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { result, error in
            if let error = error as NSError? {
                // Cross-version safe cancel detection.
                if error.domain == "com.google.GIDSignIn", error.code == -5 {
                    completion(.failure(SocialAuthError.cancelled))
                } else {
                    completion(.failure(SocialAuthError.sdk(error.localizedDescription)))
                }
                return
            }

            guard let user = result?.user else {
                completion(.failure(SocialAuthError.noCredentials("Google returned no user.")))
                return
            }

            let idToken = user.idToken?.tokenString
            let accessToken = user.accessToken.tokenString
            self.lastGoogleIDToken = idToken

            let email = user.profile?.email
            let name = [user.profile?.givenName, user.profile?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            let fullName = name.isEmpty ? nil : name
            let userID = user.userID
            let serverCode = result?.serverAuthCode

            let cred = AuthCredential(
                provider: .google,
                userID: userID,
                email: email,
                fullName: fullName,
                givenName: "",
                familyName: "",
                accessToken: accessToken,
                idToken: idToken,
                authorizationCode: serverCode,
                avatarURL: nil,
                raw: user
            )
            completion(.success(cred))
        }
    }

    // MARK: Facebook

    func signInWithFacebook(
        presentingVC: UIViewController,
        completion: @escaping (Swift.Result<AuthCredential, Error>) -> Void
    ) {
        let loginManager = LoginManager()
        loginManager.logOut()

        loginManager.logIn(permissions: ["public_profile", "email"], from: presentingVC) { result, error in
            if let error = error {
                completion(.failure(SocialAuthError.sdk(error.localizedDescription)))
                return
            }

            guard let result = result else {
                completion(.failure(SocialAuthError.noCredentials("Facebook result is nil.")))
                return
            }
            guard !result.isCancelled else {
                completion(.failure(SocialAuthError.cancelled))
                return
            }

            let tokenString = result.token?.tokenString ?? AccessToken.current?.tokenString
            guard let accessToken = tokenString else {
                completion(.failure(SocialAuthError.noCredentials("No Facebook access token.")))
                return
            }

            // Ask for id, name, email, and a high-res profile picture URL.
            // public_profile covers picture; email requires the "email" permission (already requested above).
            let request = GraphRequest(
                graphPath: "me",
                parameters: ["fields": "id,name,email,picture.width(512).height(512)"],
                httpMethod: .get
            )

            request.start { _, response, graphError in
                if let graphError = graphError {
                    // Even if Graph call fails, return a credential with at least the access token.
                    let cred = AuthCredential(
                        provider: .facebook,
                        userID: nil,
                        email: nil,
                        fullName: nil,
                        givenName: "",
                        familyName: "",
                        accessToken: accessToken,
                        idToken: nil,
                        authorizationCode: nil,
                        avatarURL: nil,
                        raw: ["graphError": graphError.localizedDescription]
                    )
                    completion(.success(cred))
                    return
                }

                let dict = response as? [String: Any]
                let userID = dict?["id"] as? String
                let name = dict?["name"] as? String
                let email = dict?["email"] as? String

                // picture → { data: { url: "...", is_silhouette: false } }
                var avatarURL: String? = nil
                if
                    let picture = dict?["picture"] as? [String: Any],
                    let data = picture["data"] as? [String: Any],
                    let url = data["url"] as? String
                {
                    avatarURL = url
                } else if let id = userID {
                    // Fallback: build a large picture URL manually.
                    avatarURL = "https://graph.facebook.com/\(id)/picture?type=large"
                }

                let cred = AuthCredential(
                    provider: .facebook,
                    userID: userID,
                    email: email,
                    fullName: name,
                    givenName: "",
                    familyName: "",
                    accessToken: accessToken,
                    idToken: nil,
                    authorizationCode: nil,
                    avatarURL: avatarURL,
                    raw: dict as Any
                )
                completion(.success(cred))
            }
        }
    }


    // MARK: Apple

    @available(iOS 13.0, *)
    func signInWithApple(
        presentingVC: UIViewController,
        completion: @escaping (Swift.Result<AuthCredential, Error>) -> Void
    ) {
        self.presentingVC = presentingVC
        self.appleSignInCompletion = completion

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        authorizationController = controller
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
}

// MARK: - Apple Delegates

@available(iOS 13.0, *)
extension SocialLoginHandler: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentingVC?.view.window ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            appleSignInCompletion?(.failure(SocialAuthError.noCredentials("Unexpected Apple credential type.")))
            appleSignInCompletion = nil
            authorizationController = nil
            return
        }

        let userID = credential.user
        let email = credential.email // First auth only
        let givenName = credential.fullName?.givenName
        let familyName = credential.fullName?.familyName
        let fullName: String? = {
            guard let name = credential.fullName else { return nil }
            let composite = PersonNameComponentsFormatter().string(from: name).trimmingCharacters(in: .whitespaces)
            return composite.isEmpty ? nil : composite
        }()

        let idToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        let authCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }

        let cred = AuthCredential(
            provider: .apple,
            userID: userID,
            email: email,
            fullName: fullName,
            givenName: givenName,
            familyName: familyName,
            accessToken: nil,
            idToken: idToken,
            authorizationCode: authCode,
            avatarURL: nil,
            raw: credential
        )

        appleSignInCompletion?(.success(cred))
        appleSignInCompletion = nil
        authorizationController = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let ns = error as NSError
        if ns.domain == ASAuthorizationError.errorDomain,
           ns.code == ASAuthorizationError.canceled.rawValue {
            appleSignInCompletion?(.failure(SocialAuthError.cancelled))
        } else {
            appleSignInCompletion?(.failure(SocialAuthError.sdk(error.localizedDescription)))
        }
        appleSignInCompletion = nil
        authorizationController = nil
    }
}
