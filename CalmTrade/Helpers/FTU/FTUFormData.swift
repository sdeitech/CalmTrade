import Foundation
import PolarBleSdk

struct FTUFormData {

    // MARK: - Your App’s Form Enums
    enum Gender: String, CaseIterable { case male = "Male", female = "Female" }
    enum TrainingBackground: String, CaseIterable { case sedentary, casual, regular, competitive }
    enum TypicalDay: String, CaseIterable { case mostlySitting, mixed, mostlyMoving }

    // MARK: - Fields
    var gender: Gender = .male
    var birthDate: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()

    var heightCm: Float = 175
    var weightKg: Float = 75

    var restingHR: Int = 60
    var vo2Max: Int = 40

    /// Optional – if nil → computed using 220 − age
    var maxHR: Int? = nil

    var training: TrainingBackground = .casual
    var typicalDay: TypicalDay = .mixed
    var sleepGoalMinutes: Int = 480    // 8 hours

    private(set) var validationErrors: [String] = []

    // MARK: - Computed Max HR (fallback)
    var computedMaxHR: Int {
        if let v = maxHR, v > 0 { return v }
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 30
        return max(80, min(220, 220 - age))
    }

    // MARK: - Normalize first
    private mutating func normalize() {
        heightCm = max(90,  min(240, heightCm))     // SwiftUI range: 90–240
        weightKg = max(15,  min(300, weightKg))     // SwiftUI range: 15–300

        restingHR = max(20, min(120, restingHR))    // SwiftUI range: 20–120
        vo2Max   = max(10, min(95,  vo2Max))        // SwiftUI range: 10–95

        sleepGoalMinutes = max(300, min(650, sleepGoalMinutes)) // SwiftUI range: 300–650
    }

    // MARK: - Validate
    mutating func validate() -> Bool {

        normalize()
        validationErrors.removeAll()

        // Age range 10–100
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        if !(10...100).contains(age) {
            validationErrors.append("Please enter a valid birth date (age 10–100).")
        }

        if !(90...240).contains(Int(heightCm)) {
            validationErrors.append("Height must be between 90–240 cm.")
        }
        if !(15...300).contains(Int(weightKg)) {
            validationErrors.append("Weight must be between 15–300 kg.")
        }
        if !(20...120).contains(restingHR) {
            validationErrors.append("Resting heart rate must be between 20–120 bpm.")
        }
        if !(10...95).contains(vo2Max) {
            validationErrors.append("VO₂max must be between 10–95.")
        }
        if !(300...650).contains(sleepGoalMinutes) {
            validationErrors.append("Sleep goal must be between 300–650 minutes (5–10 hours).")
        }

        let hr = computedMaxHR
        if !(80...220).contains(hr) {
            validationErrors.append("Max HR must be between 80–220 bpm.")
        }

        return validationErrors.isEmpty
    }
}

//
// MARK: - Mapping to PolarFirstTimeUseConfig
//

extension FTUFormData {

    func toPolarFTU(now: Date = Date()) -> PolarFirstTimeUseConfig {

        let iso = ISO8601DateFormatter()

        return PolarFirstTimeUseConfig(
            gender: (gender == .male ? .male : .female),
            birthDate: birthDate,
            height: heightCm,
            weight: weightKg,
            maxHeartRate: computedMaxHR,
            vo2Max: vo2Max,
            restingHeartRate: restingHR,
            trainingBackground: mapTrainingBackground(training),
            deviceTime: iso.string(from: now),
            typicalDay: mapTypicalDay(typicalDay),
            sleepGoalMinutes: sleepGoalMinutes
        )
    }

    // MARK: Training mapping
    private func mapTrainingBackground(_ tb: TrainingBackground) -> PolarFirstTimeUseConfig.TrainingBackground {
        switch tb {
        case .sedentary:   return .occasional
        case .casual:      return .regular
        case .regular:     return .frequent
        case .competitive: return .semiPro     // could map to .pro if you ever add elite
        }
    }

    // MARK: Typical Day mapping
    private func mapTypicalDay(_ td: TypicalDay) -> PolarFirstTimeUseConfig.TypicalDay {
        switch td {
        case .mostlySitting: return .mostlySitting
        case .mixed:         return .mostlyMoving  // no exact middle in SDK
        case .mostlyMoving:  return .mostlyMoving
        }
    }
}
