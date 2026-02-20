//
//  EmailVerificationViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 26/08/25.
//

import Foundation

final class EmailVerificationViewModel: BaseViewModel {
    
    // MARK: - Events
    var onVerificationStatusChanged: ((Bool) -> Void)?
    var onResendEmailResult: ((String?) -> Void)?  // nil => success toast
    
    // MARK: - Socket Listening (for OTP or live verification events)
    private var isListening = false
    private var observedEmail: String?
    
    /// Start listening to WebSocket messages for verification events for a specific email.
    func startListeningForVerification(email: String?) {
        guard !isListening else { return }
        observedEmail = email
        isListening = true
        
        // Ensure socket is connected if you use one:
        // SocketManager.shared.connect(token: AppInstance.shared.authToken)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSocketText(_:)),
            name: Notification.Name("WS_TEXT"),
            object: nil
        )
    }
    
    func stopListening() {
        guard isListening else { return }
        isListening = false
        NotificationCenter.default.removeObserver(self, name: Notification.Name("WS_TEXT"), object: nil)
    }
    
    deinit {
        if isListening {
            NotificationCenter.default.removeObserver(self, name: Notification.Name("WS_TEXT"), object: nil)
        }
    }
    
    // Expected socket payload example:
    // { "type": "email_verification", "email": "user@x.com", "verified": true, "otp": "123456" }
    struct VerificationEvent: Decodable {
        let type: String
        let email: String?
        let verified: Bool?
        let otp: String?
    }
    
    @objc private func handleSocketText(_ note: Notification) {
        guard let text = note.object as? String,
              let data = text.data(using: .utf8),
              let evt = try? JSONDecoder().decode(VerificationEvent.self, from: data),
              evt.type == "email_verification"
        else { return }
        
        // If we were asked to observe a specific email, filter to it.
        if let watchEmail = observedEmail, let incoming = evt.email {
            if watchEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                != incoming.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                return
            }
        }
        
        if evt.verified == true {
            stopListening()
            onVerificationStatusChanged?(true)
        }
    }
    
    // MARK: - Deep Link Verification (no Firebase)
    
    struct VerifyEmailResponse: Decodable {
        let success: Bool
        let accessToken: String?
        let refreshToken: String?
        let message: String?
    }
    
    /// Entry from DeepLinkRouter (CalmTrade://verify-email/<token> or ?token=...)
    func verifyViaDeepLink(token: String?, email: String?) {
        guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            onResendEmailResult?("Invalid or missing verification token.")
            return
        }
        verifyEmail(token: token, email: email)
    }

    private func verifyEmail(token: String, email: String?) {
        isLoading = true
        
        // Build query string
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "token", value: token)]
        if let e = email?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty {
            queryItems.append(URLQueryItem(name: "email", value: e))
        }
        
        var urlComponents = URLComponents(string: Endpoints.Auth.verifyResetLink.rawValue)
        urlComponents?.queryItems = queryItems
        
        // Final path with query
        guard let fullPath = urlComponents?.string else {
            isLoading = false
            onResendEmailResult?("Failed to build verification URL.")
            return
        }
        
        APIService().startService(with: .GET,
                                  path: fullPath,
                                  parameters: nil,
                                  files: [],
                                  modelType: VerifyEmailResponse.self) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .Success(let resp):
                    if resp?.success == true {
                        if let token = resp?.accessToken, let refreshToken = resp?.refreshToken {
                            self.updateUserToken(token, refreshToken: refreshToken)
                        }
                        self.stopListening()
                        self.onVerificationStatusChanged?(true)
                    } else {
                        self.onResendEmailResult?(resp?.message ?? "Verification failed.")
                    }
                case .Error(let message):
                    self.onResendEmailResult?(message)
                }
            }
        }
    }

    
    // MARK: - (Optional) Resend email support
    struct ResendResponse: Decodable {
        let success: Bool
        let message: String?
    }
    
    // Uncomment if/when you add a "Resend" button in the UI.
    /*
    func resendVerificationEmail(to email: String?) {
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            onResendEmailResult?("Missing email address.")
            return
        }
        isLoading = true
        
        let params = ["email": email]
        APIService().startService(with: .POST,
                                  path: Endpoints.Auth.resendVerification.rawValue, // e.g., "/auth/resend-verification"
                                  parameters: params,
                                  files: [],
                                  modelType: ResendResponse.self) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .Success(let resp):
                    if resp?.success == true {
                        self.onResendEmailResult?(nil)
                    } else {
                        self.onResendEmailResult?(resp?.message ?? "Failed to resend email.")
                    }
                case .Error(let message):
                    self.onResendEmailResult?(message)
                }
            }
        }
    }
    */
}
