//
//  SocialLoginResult.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/08/25.
//


import UIKit
import GoogleSignIn
import FirebaseAuth
import FirebaseCore
import FBSDKLoginKit
import AuthenticationServices

// MARK: - SocialLoginHandler Class

/// A centralized handler for managing different social login providers, using the latest Google Sign-In SDK.
class SocialLoginHandler: NSObject {
    
    private var presentingVC: UIViewController?
    private var appleSignInCompletion: ((Swift.Result<AuthCredential, Error>) -> Void)?
    
    // MARK: - Google Sign-In
    
    /// Initiates the Google Sign-In flow and creates a Firebase credential.
    /// This implementation is based on the latest Firebase documentation.
    /// - Parameters:
    ///   - presentingVC: The view controller that will present the Google Sign-In screen.
    ///   - completion: A closure that returns an AuthCredential on success or an Error on failure.
    func signInWithGoogle(presentingVC: UIViewController, completion: @escaping (Swift.Result<AuthCredential, Error>) -> Void) {
        
        // 1. Get the Client ID from the Firebase App. This is the recommended modern approach.
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            let customError = NSError(domain: "SocialLoginHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find Firebase ClientID."])
            completion(.failure(customError))
            return
        }
        
        // 2. Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // 3. Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { result, error in
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString
            else {
                let customError = NSError(domain: "SocialLoginHandler", code: -2, userInfo: [NSLocalizedDescriptionKey: "Google sign-in returned no user or ID token."])
                completion(.failure(customError))
                return
            }
            
            // 4. Create the Firebase credential.
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: user.accessToken.tokenString)
            
            // 5. Return the successful credential.
            completion(.success(credential))
        }
    }
    
    
    // MARK: - Facebook Sign-In
    
    /// Initiates the Facebook Sign-In flow.
    /// - Parameters:
    ///   - presentingVC: The view controller that will present the Facebook Sign-In screen.
    ///   - completion: A closure that returns an AuthCredential on success or an Error on failure.
    func signInWithFacebook(presentingVC: UIViewController, completion: @escaping (Swift.Result<AuthCredential, Error>) -> Void) {
        let loginManager = LoginManager()
        
        // 1. Start the login flow with the required permissions.
        loginManager.logIn(permissions: ["public_profile", "email"], from: presentingVC) { result, error in
            
            // 2. Handle any errors from the login manager.
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let result = result, !result.isCancelled else {
                let customError = NSError(domain: "SocialLoginHandler", code: -3, userInfo: [NSLocalizedDescriptionKey: "Facebook login was cancelled by the user."])
                completion(.failure(customError))
                return
            }
            
            // 3. Get the access token.
            guard let accessToken = result.token?.tokenString else {
                let customError = NSError(domain: "SocialLoginHandler", code: -4, userInfo: [NSLocalizedDescriptionKey: "Could not get access token from Facebook."])
                completion(.failure(customError))
                return
            }
            
            // 4. Create the Firebase credential.
            let credential = FacebookAuthProvider.credential(withAccessToken: accessToken)
            
            // 5. Return the successful credential.
            completion(.success(credential))
        }
    }
    
    // MARK: - Apple Sign-In

        /// Initiates a simplified Sign in with Apple flow (without nonce for development).
        @available(iOS 13.0, *)
    func signInWithApple(presentingVC: UIViewController, completion: @escaping (Swift.Result<AuthCredential, Error>) -> Void) {
        self.presentingVC = presentingVC
        self.appleSignInCompletion = completion
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        // The nonce is omitted in this simplified version.
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
}

// MARK: - Apple Sign-In Delegate Conformance

@available(iOS 13.0, *) // <-- FIX 2: Add availability check
extension SocialLoginHandler: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.presentingVC!.view.window!
    }
    
    func controller(_ controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            let error = NSError(domain: "SocialLoginHandler", code: -5, userInfo: [NSLocalizedDescriptionKey: "Apple Sign-In credential is not of the expected type."])
            appleSignInCompletion?(.failure(error))
            return
        }
        
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            let error = NSError(domain: "SocialLoginHandler", code: -7, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch or serialize identity token."])
            appleSignInCompletion?(.failure(error))
            return
        }
        
        // Create the Firebase credential without the rawNonce.
        let credential = OAuthProvider.credential(providerID: AuthProviderID.apple, idToken: idTokenString, accessToken: nil) // Access token is not needed here
        
        appleSignInCompletion?(.success(credential))
    }
    
    func controller(_ controller: ASAuthorizationController, didCompleteWithError error: Error) {
        appleSignInCompletion?(.failure(error))
    }
}

