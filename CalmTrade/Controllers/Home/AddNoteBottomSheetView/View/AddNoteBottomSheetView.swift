//
//  AddNoteBottomSheetView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 26/12/25.
//


import SwiftUI

struct AddNoteBottomSheetView: View {

    @ObservedObject var viewModel: AddNoteViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 16) {

                Text("Add Note")
                    .font(.custom("Helvetica Neue", size: 20))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.top, 16)

                // TITLE FIELD (Dropdown OR TextField)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.custom("Helvetica Neue", size: 13))
                        .foregroundColor(.gray)

                    if viewModel.selectedOption == .custom {
                        TextField("Enter title", text: $viewModel.titleText)
                            .font(.custom("Helvetica Neue", size: 16))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                    } else {
                        Menu {
                            ForEach(AddNoteViewModel.TitleOption.allCases, id: \.self) { option in
                                Button(option.rawValue) {
                                    viewModel.selectedOption = option
                                    viewModel.titleText = ""
                                }
                            }
                        } label: {
                            HStack {
                                Text(viewModel.selectedOption.rawValue)
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.gray)
                            }
                            .font(.custom("Helvetica Neue", size: 16))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                        }
                    }
                }

                // DESCRIPTION
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.custom("Helvetica Neue", size: 13))
                        .foregroundColor(.gray)

                    TextEditor(text: $viewModel.descriptionText)
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

                // SAVE
                Button {
                    viewModel.save()
                } label: {
                    ZStack {
                        if viewModel.isLoading {
                            ProgressView().tint(.white)
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
            if saved { dismiss() }
        }
    }
}

