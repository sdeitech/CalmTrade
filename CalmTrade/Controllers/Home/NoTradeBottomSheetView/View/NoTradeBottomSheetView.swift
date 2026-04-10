//
//  NoTradeBottomSheetView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 26/12/25.
//


import SwiftUI

struct NoTradeBottomSheetView: View {

    @ObservedObject var viewModel: NoTradeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 16) {

                // Title
                Text("No Trades")
                    .font(.custom("Helvetica Neue", size: 20))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.top, 16)

                // Symbol field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Symbol")
                        .font(.custom("Helvetica Neue", size: 13))
                        .foregroundColor(.gray)

                    TextField("TSLA", text: Binding(
                        get: { viewModel.symbol },
                        set: { viewModel.symbol = $0.uppercased() }
                    ))
                        .font(.custom("Helvetica Neue", size: 16))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.characters)
                }
                
                // Entry Price field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Entry Price")
                        .font(.custom("Helvetica Neue", size: 13))
                        .foregroundColor(.gray)

                    TextField("$", text: $viewModel.entryPrice)
                        .font(.custom("Helvetica Neue", size: 16))
                        .foregroundColor(.white)
                        .padding(12)
                        .keyboardType(.decimalPad)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                }

                // Note field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Note")
                        .font(.custom("Helvetica Neue", size: 13))
                        .foregroundColor(.gray)

                    TextEditor(text: $viewModel.reason)
                        .font(.custom("Helvetica Neue", size: 16))
                        .foregroundColor(.white)
                        .frame(height: 90)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                        .scrollContentBackground(.hidden)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.custom("Helvetica Neue", size: 13))
                        .foregroundColor(.red)
                }

                // Save Button
                Button {
                    viewModel.save()
                } label: {
                    ZStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Save")
                                .font(.custom("Helvetica Neue", size: 17))
                                .fontWeight(.medium)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.25, green: 0.53, blue: 0.90)) // Blue
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isLoading)

            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.16))
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: viewModel.didSave) { saved in
            if saved {
                dismiss()
            }
        }
    }
}

