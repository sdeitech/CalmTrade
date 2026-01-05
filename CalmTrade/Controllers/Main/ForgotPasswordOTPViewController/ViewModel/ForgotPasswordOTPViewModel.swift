//
//  ForgotPasswordOTPViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 07/10/25.
//

import Foundation
import UIKit

final class ForgotPasswordOTPViewModel: BaseViewModel {

    // MARK: - Deps
    private let repo: UserRepositoryProtocol

    // MARK: - Outputs
    var onLoading: ((Bool) -> Void)?
    var onError: ((String) -> Void)?
    /// Now passes the backend token to the VC for the reset step
    var onVerified: (() -> Void)?
    var onResent: ((String) -> Void)?

    // Countdown UI
    var onResendTick: ((Int) -> Void)?          // seconds left
    var onResendAvailability: ((Bool) -> Void)? // true = enabled

    // MARK: - Timer state
    private var countdownTimer: Timer?
    private var countdownEndsAt: Date?

    init(repo: UserRepositoryProtocol = UserRepository()) {
        self.repo = repo
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    deinit {
        stopCountdown()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public
    func verify(email: String?, enteredOTP: String) {
        let code = enteredOTP.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            onError?("Missing email address."); return
        }
        guard !code.isEmpty else { onError?("Please enter the code."); return }
        guard code.count >= 4 else { onError?("Please enter the complete code."); return }

        onLoading?(true)
        repo.verifyOTP(email: email, otp: code) { [weak self] result in
            guard let self = self else { return }
            self.onLoading?(false)
            switch result {
            case .Success(let resp):
                if resp?.success == true{//, let token = resp?.token, !token.isEmpty {
                    self.onVerified?()                 // <-- EMIT TOKEN UP
                } else {
                    self.onError?(resp?.message ?? "Verification failed. Please try again.")
                }
            case .Error(let message):
                self.onError?(message)
            }
        }
    }

    /// Call when tapping "Resend Code". Only proceeds if enabled.
    func resendCode(to email: String?) {
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            onError?("Missing email address."); return
        }
        // If countdown running → disabled
        if isCountdownActive {
            onResendAvailability?(false)
            return
        }

        // Disable immediately to avoid double taps
        onResendAvailability?(false)
        onLoading?(true)
        // Use your existing user-module method; if it's named `forgotPasswordRequest`, swap it here.
        repo.forgotPassword(email: email) { [weak self] result in
            guard let self = self else { return }
            self.onLoading?(false)
            switch result {
            case .Success(let msg):
                self.onResent?(msg?.message ?? "A new code has been sent to your email.")
                self.beginCountdown(seconds: 60) // restart for 60s after resend
            case .Error(let message):
                // Re-enable so the user can try again
                self.onError?(message)
                self.onResendAvailability?(true)
            }
        }
    }

    // MARK: - Countdown API
    var isCountdownActive: Bool {
        guard let end = countdownEndsAt else { return false }
        return end.timeIntervalSinceNow > 0
    }

    func beginCountdown(seconds: Int) {
        stopCountdown()
        countdownEndsAt = Date().addingTimeInterval(TimeInterval(seconds))
        onResendAvailability?(false)
        tick() // fire immediately so UI updates at once
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(countdownTimer!, forMode: .common)
    }

    func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownEndsAt = nil
    }

    private func tick() {
        guard let end = countdownEndsAt else {
            onResendAvailability?(true)
            onResendTick?(0)
            return
        }
        let remaining = max(0, Int(end.timeIntervalSinceNow.rounded(.down)))
        onResendTick?(remaining)
        if remaining <= 0 {
            stopCountdown()
            onResendAvailability?(true)
        }
    }

    @objc private func appWillEnterForeground() {
        // Recompute remaining on foreground for accuracy
        tick()
    }
}

// MARK: - Helper to allow `resp?.value(forKey:)` fallback if your repo returns `Decodable?`
private protocol KVCReadable { func value(forKey key: String) -> Any? }
//extension Optional: KVCReadable where Wrapped == Decodable {
//    func value(forKey key: String) -> Any? {
//        re
//    }
//}
