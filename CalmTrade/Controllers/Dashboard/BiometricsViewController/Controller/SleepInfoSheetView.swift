//
//  SleepInfoSheetView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 27/10/25.
//


import SwiftUI

public struct SleepInfoSheetView: View {
    // Callbacks into UIKit / host
    public var onAdd: (_ dontShowAgain: Bool) -> Void
    public var onLater: (_ dontShowAgain: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var dontShowAgain = false

    public init(onAdd: @escaping (_ dontShowAgain: Bool) -> Void,
                onLater: @escaping (_ dontShowAgain: Bool) -> Void) {
        self.onAdd = onAdd
        self.onLater = onLater
    }

    public var body: some View {
        VStack(spacing: 18) {
            // Grabber mimic (since we use pageSheet)
            Capsule().fill(.secondary.opacity(0.4)).frame(width: 36, height: 4).padding(.top, 6)

            // Title
            HStack(spacing: 10) {
                Image(systemName: "moon.zzz.fill")
                    .imageScale(.large)
                    .foregroundStyle(.indigo)
                Text("Add sleep in Apple Health")
                    .font(.title3).bold()
                    .foregroundStyle(.primary)
                Spacer()
            }

            // Pretty card with steps
            VStack(alignment: .leading, spacing: 12) {
                StepRow(index: 1, text: "Open the Health app")
                StepRow(index: 2, text: "Tap **Browse** (bottom-right)")
                StepRow(index: 3, text: "Find and tap **Sleep**")
                StepRow(index: 4, text: "Scroll down and tap **Add Data**")
                StepRow(index: 5, text: "Choose **In Bed** or **Asleep**")
                StepRow(index: 6, text: "Set **Start** and **End** time")
                StepRow(index: 7, text: "Tap **Add** (top-right)")
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.15))
            )

            // “Don’t show again” toggle (checkbox style)
            Toggle(isOn: $dontShowAgain) {
                Text("Don’t show again").font(.body)
            }
            .toggleStyle(.switch)
            .tint(.indigo)

            // Buttons
            HStack(spacing: 12) {
                Button("Later") {
                    dismiss()
                    onLater(dontShowAgain)
                }
                .buttonStyle(.bordered)

                Button {
                    dismiss()
                    onAdd(dontShowAgain)
                } label: {
                    Label("Add Sleep", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
            }
            .font(.headline)

            Spacer(minLength: 8)
        }
        .padding(20)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityElement(children: .contain)
    }
}

private struct StepRow: View {
    let index: Int
    let text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            ZStack {
                Circle().fill(Color.indigo.opacity(0.15)).frame(width: 26, height: 26)
                Text("\(index)").font(.footnote).bold().foregroundStyle(.indigo)
            }
            Text(try! AttributedString(markdown: text))
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}
