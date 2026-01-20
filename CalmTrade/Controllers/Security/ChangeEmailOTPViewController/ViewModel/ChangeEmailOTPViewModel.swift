//
//  ChangeEmailOTPViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/01/26.
//


import Foundation
import UIKit

final class ChangeEmailOTPViewModel {

    // MARK: - State
    private(set) var oldEmail: String = ""
    private(set) var newEmail: String = ""

    // MARK: - Outputs
    var onLoading: ((Bool) -> Void)?
    var onError: ((String) -> Void)?
    var onSuccess: ((_ newEmail: String) -> Void)?
    var onResent: (() -> Void)?

    // Countdown
    var onResendTick: ((Int) -> Void)?
    var onResendAvailability: ((Bool) -> Void)?

    // MARK: - Timer
    private var countdownTimer: Timer?
    private var countdownEndsAt: Date?

    // MARK: - Config

    func configure(oldEmail: String, newEmail: String) {
        self.oldEmail = oldEmail
        self.newEmail = newEmail
    }

    // MARK: - Resend OTP

    func resendOTP() {
        guard !isCountdownActive else { return }

        let params: [String: Any] = [
            "oldEmail": oldEmail,
            "newEmail": newEmail
        ]

        onLoading?(true)
        onResendAvailability?(false)

        APIService().startService(with: .POST,
                                  path: "user/change-email-request",
                                  parameters: params,
                                  files: nil,
                                  modelType: GenericResponse.self, completion: { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoading?(false)

                switch result {
                case .Success(let response):
                    guard response?.success == true else {
                        self?.onError?(response?.message ?? "Failed to resend OTP.")
                        self?.onResendAvailability?(true)
                        return
                    }
                    self?.onResent?()
                    self?.beginCountdown(seconds: 35)

                case .Error(let message):
                    self?.onError?(message)
                    self?.onResendAvailability?(true)
                }
            }
        }
        )
    }

    // MARK: - Verify OTP

    func verifyOTP(_ otp: String) {

        let code = otp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count == 4 else {
            onError?("Please enter a valid 4-digit OTP.")
            return
        }

        let params: [String: Any] = [
            "oldEmail": oldEmail,
            "newEmail": newEmail,
            "otp": code
        ]

        onLoading?(true)

        APIService().startService(
            with: .POST,
            path: "user/verify-change-email",
            parameters: params,
            files: nil,
            modelType: VerifyChangeEmailResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoading?(false)

                switch result {
                case .Success(let response):
                    guard response?.success == true else {
                        self?.onError?(response?.message ?? "OTP verification failed.")
                        return
                    }
                    self?.onSuccess?(response?.newEmail ?? "")

                case .Error(let message):
                    self?.onError?(message)
                }
            }
        }
    }

    // MARK: - Countdown Logic (same as ForgotPassword)

    private var isCountdownActive: Bool {
        guard let end = countdownEndsAt else { return false }
        return end.timeIntervalSinceNow > 0
    }

    func beginCountdown(seconds: Int) {
        stopCountdown()
        countdownEndsAt = Date().addingTimeInterval(TimeInterval(seconds))
        onResendAvailability?(false)
        tick()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(countdownTimer!, forMode: .common)
    }

    private func stopCountdown() {
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

        let remaining = max(0, Int(end.timeIntervalSinceNow))
        onResendTick?(remaining)

        if remaining <= 0 {
            stopCountdown()
            onResendAvailability?(true)
        }
    }
}

