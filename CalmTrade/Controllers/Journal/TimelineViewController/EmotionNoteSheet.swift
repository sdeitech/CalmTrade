//
//  EmotionNoteSheet.swift
//  CalmTrade
//
//  Created by Anas Parekh on 21/01/26.
//


import SwiftUI

struct EmotionBottomSheetView: View {

    @ObservedObject var viewModel: EmotionNoteViewModel
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 16) {

                // Title
                Text("Add Note")
                    .font(.custom("Helvetica Neue", size: 20))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.top, 16)

                // Note field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Note")
                        .font(.custom("Helvetica Neue", size: 13))
                        .foregroundColor(.gray)

                    TextEditor(text: $viewModel.content)
                        .font(.custom("Helvetica Neue", size: 16))
                        .foregroundColor(.white)
                        .frame(height: 100)
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
                    .background(Color(red: 0.25, green: 0.53, blue: 0.90))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isLoading || viewModel.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

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
                onSaved()
            }
        }
    }
}
