//
//  OTPVerificationView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 05/01/26.
//


import SwiftUI

struct OTPVerificationView: View {

    @StateObject var viewModel: OTPVerificationViewModel
    @FocusState private var isFocused: Bool
    @State private var otp: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 28) {

            Spacer()

            VStack(spacing: 8) {
                Text("Verify Authentication")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(viewModel.isDisabling
                     ? "Enter the code to disable 2-factor authentication"
                     : "Enter the 6-digit code from your authenticator app")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            otpField

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            Button(action: submit) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Verify")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(otp.count != 6 || isLoading)

            Spacer()
        }
        .padding()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isFocused = true
            }
        }
    }

    private var otpField: some View {
        TextField("••••••", text: $otp)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .multilineTextAlignment(.center)
            .font(.system(size: 28, weight: .medium, design: .monospaced))
            .focused($isFocused)
            .onChange(of: otp) { newValue in
                otp = String(newValue.filter(\.isNumber).prefix(6))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3))
            )
    }

    private func submit() {
        guard otp.count == 6 else { return }
        isLoading = true
        errorMessage = nil

        viewModel.submit(code: otp) { success, error in
            isLoading = false
            if success {
                viewModel.onSuccess?()
            } else {
                errorMessage = error ?? "Invalid verification code"
                otp = ""
                isFocused = true
            }
        }
    }
}
