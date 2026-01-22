//
//  EditEmotionSheet.swift
//  CalmTrade
//
//  Created by Anas Parekh on 21/01/26.
//

import SwiftUI

struct EditEmotionSheet: View {

    let title: String
    let color: Color
    let initialText: String?
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""

    var body: some View {
        VStack(spacing: 24) {

            Text(title)
                .font(.title3.bold())
                .foregroundColor(color)

            TextField("Emotion", text: $text)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

            Button("Save") {
                onSave(text)
                dismiss()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(14)

        }
        .padding()
        .onAppear { text = initialText ?? "" }
    }
}
