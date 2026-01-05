//
//  FTUSetupView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 18/12/25.
//


import SwiftUI
import PolarBleSdk

struct FTUSetupView: View {

    @Environment(\.presentationMode) var presentationMode
    var onSubmit: (PolarFirstTimeUseConfig) -> Void

    @State private var gender: PolarFirstTimeUseConfig.Gender = .male
    @State private var height: String = "175"
    @State private var weight: String = "70"
    @State private var maxHeartRate: String = ""
    @State private var restingHeartRate: String = "55"
    @State private var vo2Max: String = "45"
    @State private var trainingBackground: PolarFirstTimeUseConfig.TrainingBackground = .regular
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date())!
    @State private var typicalDay: PolarFirstTimeUseConfig.TypicalDay = .mostlySitting
    @State private var sleepGoalMinutes: String = "480"

    @StateObject private var formValidation = FormValidation()
    
    private let trainingOptions: [PolarFirstTimeUseConfig.TrainingBackground] = [
        .occasional,
        .regular,
        .frequent,
        .heavy,
        .semiPro,
        .pro
    ]
    
    private func trainingLabel(_ t: PolarFirstTimeUseConfig.TrainingBackground) -> String {
        switch t {
        case .occasional: return "Occasional"
        case .regular:    return "Regular"
        case .frequent:   return "Frequent"
        case .heavy:      return "Heavy"
        case .semiPro:    return "Semi-Pro"
        case .pro:        return "Pro"
        default:          return "Unknown"
        }
    }


    var body: some View {
        NavigationView {
            Form {

                Section(header: Text("Personal Information")) {
                    Picker("Gender", selection: $gender) {
                        Text("Male").tag(PolarFirstTimeUseConfig.Gender.male)
                        Text("Female").tag(PolarFirstTimeUseConfig.Gender.female)
                    }

                    DatePicker("Birth Date",
                               selection: $birthDate,
                               displayedComponents: .date)

                    TextField("Height (cm)", text: $height)
                        .keyboardType(.numberPad)
                        .validation((90...240).contains(Int(height) ?? -1),
                                    guide: "90–240 cm",
                                    formValidation: formValidation)

                    TextField("Weight (kg)", text: $weight)
                        .keyboardType(.numberPad)
                        .validation((15...300).contains(Int(weight) ?? -1),
                                    guide: "15–300 kg",
                                    formValidation: formValidation)
                }

                Section(header: Text("Heart Rates")) {
                    TextField("Max HR (bpm)", text: $maxHeartRate)
                        .keyboardType(.numberPad)
                        .validation((100...240).contains(Int(maxHeartRate) ?? 150),
                                    guide: "100–240 bpm",
                                    formValidation: formValidation)

                    TextField("Resting HR (bpm)", text: $restingHeartRate)
                        .keyboardType(.numberPad)
                        .validation((20...120).contains(Int(restingHeartRate) ?? -1),
                                    guide: "20–120 bpm",
                                    formValidation: formValidation)
                }

                // MARK: - Fitness
                Section(
                    header: Text("Fitness"),
                    content: {
                        TextField("VO2 Max", text: $vo2Max)
                            .keyboardType(.numberPad)
                            .validation((10...95).contains(Int(vo2Max) ?? -1),
                                        guide: "10–95",
                                        formValidation: formValidation)

                        Picker("Training Background", selection: $trainingBackground) {
                            ForEach(trainingOptions, id: \.self) { option in
                                Text(trainingLabel(option)).tag(option)
                            }
                        }
                    }
                )

                Section(header: Text("Daily Activity")) {
                    Picker("Typical Day", selection: $typicalDay) {
                        Text("Mostly Sitting").tag(PolarFirstTimeUseConfig.TypicalDay.mostlySitting)
                        Text("Mostly Moving").tag(PolarFirstTimeUseConfig.TypicalDay.mostlyMoving)
                    }

                    TextField("Sleep Goal (minutes)", text: $sleepGoalMinutes)
                        .keyboardType(.numberPad)
                        .validation((300...650).contains(Int(sleepGoalMinutes) ?? -1),
                                    guide: "300–650",
                                    formValidation: formValidation)
                }
            }

            .navigationTitle("Device Setup")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") { submit() }
                        .disabled(!formValidation.isOK)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }

    private func submit() {

        let maxHRValue: Int = {
            if let v = Int(maxHeartRate), v > 0 { return v }
            let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 25
            return max(80, min(220, 220 - age))
        }()

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let config = PolarFirstTimeUseConfig(
            gender: gender,
            birthDate: birthDate,
            height: Float(height) ?? 0,
            weight: Float(weight) ?? 0,
            maxHeartRate: maxHRValue,
            vo2Max: Int(vo2Max) ?? 0,
            restingHeartRate: Int(restingHeartRate) ?? 0,
            trainingBackground: trainingBackground,
            deviceTime: iso.string(from: Date()),
            typicalDay: typicalDay,
            sleepGoalMinutes: Int(sleepGoalMinutes) ?? 480
        )

        onSubmit(config)
        presentationMode.wrappedValue.dismiss()
    }
}


class FormValidation: ObservableObject {
    private var shownGuides = Set<String>()
    func add (_ validation: String) {
        shownGuides.insert(validation)
        if (isOK) { isOK = false }
    }
    func remove(_ validation: String) {
        shownGuides.remove(validation)
        if shownGuides.isEmpty && isOK == false {
            isOK = true
        }
    }
    @Published var isOK: Bool = true
}

fileprivate extension View {
    func validation(_ valid: Bool, guide: String, formValidation: FormValidation) -> some View {
        Task { @MainActor in
            if !valid {
                formValidation.add(guide)
            } else {
                formValidation.remove(guide)
            }
        }
        return ZStack {
            self
                .frame(maxWidth: .infinity)
            Text(valid ? "✔" : guide)
                .font(.footnote)
                .opacity(valid ? 1.0 : 0.25)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}
