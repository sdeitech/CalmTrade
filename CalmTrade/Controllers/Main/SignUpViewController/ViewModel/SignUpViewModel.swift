//
//  SignUpViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/08/25.
//

import Foundation
import UIKit
import SafariServices
import FirebaseAuth

class SignUpViewModel: BaseViewModel {
    
    var isCheckboxSelected: Bool = false
    
    // Define your colors here to easily change them later
    let focusedColor = UIColor(named: "selectedTextfieldColor")
    let normalColor = UIColor(named: "unselectedTextFieldColor")
    
    // Terms Checkbox
    let selectedImage = UIImage(named: "termsCheckbox-selected")
    let unselectedImage = UIImage(named: "termsCheckbox-unselected")
    
    /// Helper function to find the character index at a specific point within a UILabel.
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
        let labelSize = label.bounds.size
        textContainer.size = labelSize
        
        let characterIndex = layoutManager.characterIndex(for: point, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        
        return characterIndex
    }
    
    /// Helper function to open a URL in a Safari View Controller.
    func openURL(urlString: String, in context: UIViewController) {
        guard let url = URL(string: urlString) else {
            print("Error: Invalid URL string.")
            return
        }
        let safariVC = SFSafariViewController(url: url)
        
        DispatchQueue.main.async {
            context.present(safariVC, animated: true, completion: nil)
        }
        
    }
    
    func setupTappableLabel(label: UILabel, action: Selector) {
        // 1. Define the full text and the parts you want to make tappable.
        let fullText = "I agree to the Terms & Conditions and Data Privacy Policy"
        let tappableTextTerms = "Terms & Conditions"
        let tappableTextPolicy = "Data Privacy Policy"
        
        // 2. Create an NSMutableAttributedString from the full text.
        let attributedString = NSMutableAttributedString(string: fullText)
        
        // 3. Define the attributes for the tappable parts (bold, underline, color).
        let tappableAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: label.font.pointSize),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: UIColor.systemBlue // Or any color you prefer for links
        ]
        
        // 4. Find the ranges of the tappable text.
        guard let termsRange = fullText.range(of: tappableTextTerms),
              let policyRange = fullText.range(of: tappableTextPolicy) else {
            print("Error: Tappable text not found in the full string.")
            return
        }
        
        let nsRangeTerms = NSRange(termsRange, in: fullText)
        let nsRangePolicy = NSRange(policyRange, in: fullText)
        
        // 5. Apply the attributes to the ranges.
        attributedString.addAttributes(tappableAttributes, range: nsRangeTerms)
        attributedString.addAttributes(tappableAttributes, range: nsRangePolicy)
        
        DispatchQueue.main.async {
            // 6. Set the attributed text on the label.
            label.attributedText = attributedString
            
            // 7. Add a tap gesture recognizer to the label.
            let tapGesture = UITapGestureRecognizer(target: self, action: action)
            label.addGestureRecognizer(tapGesture)
            label.isUserInteractionEnabled = true // IMPORTANT: This must be true for taps to be recognized.
        }
        
    }
    
    // MARK: - Validation Methods
    
    /// Validates all fields of the sign-up form based on the required criteria.
    /// - Returns: A tuple containing a boolean for validity and an optional error message string.
    func validate(fullName: String?, email: String?, phoneNumber: String?, password: String?) -> (isValid: Bool, error: String?) {
        
        // 1. Validate Full Name
        guard let name = fullName, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return (false, "Please enter your full name.") // Replace with your AlertMessage enum
        }
        
        // 2. Validate Email
        guard let mail = email, !mail.trimmingCharacters(in: .whitespaces).isEmpty else {
            return (false, "Please enter your email address.")
        }
        
        guard mail.isValidEmail() else {
            return (false, "Please enter a valid email address.")
        }
        
        // 3. Validate Phone Number
        guard let phone = phoneNumber, !phone.trimmingCharacters(in: .whitespaces).isEmpty else {
            return (false, "Please enter your phone number.")
        }
        
        // 4. Validate Password
        guard let pswd = password, !pswd.isEmpty else {
            return (false, "Please enter a password.")
        }
        
        guard pswd.count >= 8 else {
            return (false, "Password must be at least 8 characters long.")
        }
        
        guard pswd.containsUppercaseLetter() else {
            return (false, "Password must contain at least one uppercase letter.")
        }
        
        guard pswd.containsSpecialCharacter() else {
            return (false, "Password must contain at least one special character.")
        }
        
        guard self.isCheckboxSelected else {
            return (false, "Please accept the terms and conditions.")
        }
        
        // All validation checks passed
        return (true, nil)
    }
    
    // MARK: - Firebase Actions
    
    /// Creates a new user with email and password, and sends a verification email.
    /// - Parameter completion: A closure that returns true on success, or false with an error on failure.
    func createUser(email: String, password: String, fullName: String, completion: @escaping (Bool, Error?) -> Void) {
        // 1. Create the user in Firebase Auth.
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                // If user creation fails, report the error.
                completion(false, error)
                return
            }
            
            guard let user = authResult?.user else {
                // This case should rarely happen, but it's good to handle.
                let customError = NSError(domain: "SignUpViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User creation returned no user object."])
                completion(false, customError)
                return
            }
            
            // 2. Send the verification email.
            user.sendEmailVerification { error in
                if let error = error {
                    // If sending the email fails, report the error.
                    completion(false, error)
                    return
                }
                
                // --- SUCCESS ---
                // User was created and verification email was sent successfully.
                print("Successfully created user and sent verification email.")
                completion(true, nil)
            }
        }
    }
}
