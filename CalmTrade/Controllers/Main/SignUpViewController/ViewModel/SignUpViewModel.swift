//
//  SignUpViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/08/25.
//

import Foundation
import UIKit
import SafariServices
import Combine

final class SignUpViewModel: BaseViewModel {

    // MARK: - UI State
    var isCheckboxSelected: Bool = false

    let focusedColor = UIColor(named: "selectedTextfieldColor")
    let normalColor  = UIColor(named: "unselectedTextFieldColor")

    let selectedImage   = UIImage(named: "termsCheckbox-selected")
    let unselectedImage = UIImage(named: "termsCheckbox-unselected")

    // Final unified user (after profile fetch)
    @Published var user: User?
    @Published var error: String?

    private let repo: UserRepositoryProtocol
    private let profileService = ProfileService()

    init(repo: UserRepositoryProtocol = UserRepository()) {
        self.repo = repo
    }

    // MARK: - Register Response Model
    struct RegisterResponse: Decodable {
        let success: Bool
        let message: String?
        let isVerified: Bool?
        let accessToken: String?
        // No user object — login requires profile fetch
    }

    // MARK: - Helpers
    func characterIndex(for point: CGPoint, in label: UILabel) -> Int? {
        guard let attributedText = label.attributedText else { return nil }
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: .zero)
        let textStorage = NSTextStorage(attributedString: attributedText)
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        textContainer.lineFragmentPadding = 0.0
        textContainer.lineBreakMode = label.lineBreakMode
        textContainer.maximumNumberOfLines = label.numberOfLines
        textContainer.size = label.bounds.size
        return layoutManager.characterIndex(for: point, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
    }

    func openURL(urlString: String, in context: UIViewController) {
        guard let url = URL(string: urlString) else { return }
        DispatchQueue.main.async {
            context.present(SFSafariViewController(url: url), animated: true)
        }
    }

    func setupTappableLabel(label: UILabel, action: Selector) {
        let fullText = "I agree to the Terms & Conditions and Data Privacy Policy"
        let terms = "Terms & Conditions"
        let policy = "Data Privacy Policy"

        let attributed = NSMutableAttributedString(string: fullText)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: label.font.pointSize),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: UIColor.systemBlue
        ]

        if let r1 = fullText.range(of: terms) {
            attributed.addAttributes(attrs, range: NSRange(r1, in: fullText))
        }
        if let r2 = fullText.range(of: policy) {
            attributed.addAttributes(attrs, range: NSRange(r2, in: fullText))
        }

        DispatchQueue.main.async {
            label.attributedText = attributed
            label.isUserInteractionEnabled = true
            label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))
        }
    }

    // MARK: - Validation
    func validate(fullName: String?, email: String?, phoneNumber: String?, password: String?) -> (isValid: Bool, error: String?) {

        guard let name = fullName?.trimmingCharacters(in: .whitespaces), !name.isEmpty
        else { return (false, "Please enter your full name.") }

        guard let mail = email?.trimmingCharacters(in: .whitespaces), !mail.isEmpty
        else { return (false, "Please enter your email address.") }
        guard mail.isValidEmail() else { return (false, "Please enter a valid email address.") }

        guard let phone = phoneNumber?.trimmingCharacters(in: .whitespaces), !phone.isEmpty
        else { return (false, "Please enter your phone number.") }

        guard let pswd = password, !pswd.isEmpty
        else { return (false, "Please enter a password.") }

        guard pswd.count >= 8 else { return (false, "Password must be at least 8 characters long.") }
        guard pswd.containsUppercaseLetter() else { return (false, "Password must contain at least one uppercase letter.") }
        guard pswd.containsSpecialCharacter() else { return (false, "Password must contain at least one special character.") }

        guard isCheckboxSelected else { return (false, "Please accept the terms and conditions.") }

        return (true, nil)
    }

    // MARK: - Register (Backend)
    func register(fullName: String,
                  email: String,
                  phone: String,
                  password: String,
                  completion: @escaping (Bool, String?) -> Void) {

        isLoading = true

        let params: [String: Any] = [
            "name": fullName,
            "email": email,
            "phoneNumber": phone,
            "password": password
        ]

        APIService().startService(
            with: .POST,
            path: Endpoints.Auth.register.rawValue,
            parameters: params,
            files: [],
            modelType: RegisterResponseModel.self
        ) { result in

            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .Success(let resp):
                    completion(resp?.success ?? false, resp?.message)

                case .Error(let msg):
                    completion(false, msg)
                }
            }
        }
    }

    // MARK: - SOCIAL LOGIN (Google / Apple / Facebook)
    // THESE SHOULD AUTO-LOGIN → so fetch profile + create unified User

    private func finalizeSocialLogin(resp: AuthResponse?,
                                     completion: @escaping (Bool, String?, Bool) -> Void) {

        let isFirst = resp?.newAccount ?? false

        guard let resp, resp.success else {
            completion(false, resp?.message, isFirst)
            return
        }

        guard let token = resp.accessToken else {
            completion(false, "Missing access token", isFirst)
            return
        }

        // Fetch profile after social login
        profileService.refreshProfile(accessToken: token) { [weak self] dto, err in
            guard let self else { return }

            if let dto = dto {
                self.user = dto

                SocketClient.shared.connect(with: token)

                completion(true, nil, isFirst)

            } else {
                completion(false, err ?? "Failed loading profile", isFirst)
            }
        }
    }

    // MARK: - Google
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
                    guard let token = resp?.accessToken, let refreshToken = resp?.refreshToken else {
                        completion(false, "Missing access token", resp?.isFirstTimeUser ?? false)
                        return
                    }
                    self.updateUserToken(token, refreshToken: refreshToken)
                    self.finalizeSocialLogin(resp: resp, completion: completion)

                case .Error(let msg):
                    completion(false, msg, false)
                }
            }
        }
    }

    // MARK: - Apple
    func appleAuth(identityToken: String,
                   authorizationCode: String,
                   givenName: String,
                   familyName: String,
                   completion: @escaping (_ success: Bool, _ message: String?, _ isFirstTimeUser: Bool) -> Void) {

        isLoading = true
        error = nil

        repo.appleAuth(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            givenName: givenName,
            familyName: familyName
        ) { [weak self] result in

            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                switch result {
                case .Success(let resp):
                    guard let token = resp?.accessToken, let refreshToken = resp?.refreshToken else {
                        completion(false, "Missing access token", resp?.isFirstTimeUser ?? false)
                        return
                    }
                    self.updateUserToken(token, refreshToken: refreshToken)
                    self.finalizeSocialLogin(resp: resp, completion: completion)

                case .Error(let msg):
                    completion(false, msg, false)
                }
            }
        }
    }

    // MARK: - Facebook
    func facebookAuth(accessToken: String,
                      name: String,
                      email: String,
                      userId: String,
                      imageUrl: String,
                      completion: @escaping (_ success: Bool, _ message: String?, _ isFirstTimeUser: Bool) -> Void) {

        isLoading = true
        error = nil

        repo.facebookAuth(
            accessToken: accessToken,
            name: name,
            email: email,
            userId: userId,
            imageUrl: imageUrl
        ) { [weak self] result in

            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                switch result {
                case .Success(let resp):
                    guard let token = resp?.accessToken, let refreshToken = resp?.refreshToken else {
                        completion(false, "Missing access token", resp?.isFirstTimeUser ?? false)
                        return
                    }
                    self.updateUserToken(token, refreshToken: refreshToken)
                    self.finalizeSocialLogin(resp: resp, completion: completion)

                case .Error(let msg):
                    completion(false, msg, false)
                }
            }
        }
    }
}
