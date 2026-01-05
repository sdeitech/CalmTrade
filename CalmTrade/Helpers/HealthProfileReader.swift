//
//  HealthProfileReader.swift
//  CalmTrade
//
//  Created by Anas Parekh on 29/10/25.
//


import Foundation
import HealthKit

final class HealthProfileReader {
    static let shared = HealthProfileReader()
    private init() {}

    private let store = HKHealthStore()

    // Public: ask for permission and fetch a Polar360Snapshot (age/sex/height/weight)
    func requestAndFetch(completion: @escaping (Polar360Snapshot?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(nil); return
        }

        // Build typed objects first
        let charSex   = HKObjectType.characteristicType(forIdentifier: .biologicalSex)!
        let charDOB   = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        let qtyHeight = HKObjectType.quantityType(forIdentifier: .height)!
        let qtyWeight = HKObjectType.quantityType(forIdentifier: .bodyMass)!

        // Explicit element type so Swift doesn't guess
        let charTypes: Set<HKObjectType> = [charSex, charDOB]
        let qtyTypes:  Set<HKObjectType> = [qtyHeight, qtyWeight]
        let readTypes: Set<HKObjectType> = charTypes.union(qtyTypes)

        store.requestAuthorization(toShare: [], read: readTypes) { [weak self] ok, _ in
            guard ok, let self = self else { completion(nil); return }
            self.readSnapshot(completion: completion)
        }
    }

    // MARK: - Private

    private func readSnapshot(completion: @escaping (Polar360Snapshot?) -> Void) {
        var snap = Polar360Snapshot.empty

        // DOB + Sex
        if let dob = try? store.dateOfBirthComponents().date {
            snap.ageYears = Calendar.current.dateComponents([.year], from: dob, to: Date()).year
        }
        if let sex = try? store.biologicalSex().biologicalSex {
            switch sex {
            case .female: snap.biologicalSex = "Female"
            case .male:   snap.biologicalSex = "Male"
            case .other:  snap.biologicalSex = "Other"
            default:      break
            }
        }

        // Latest height/weight
        let heightType = HKObjectType.quantityType(forIdentifier: .height)!
        let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass)!

        let group = DispatchGroup()

        group.enter()
        latestSample(for: heightType, unit: .meter()) { meters in
            if let m = meters { snap.heightCm = m * 100.0 }
            group.leave()
        }

        group.enter()
        latestSample(for: weightType, unit: .gram()) { grams in
            if let g = grams { snap.weightKg = g / 1000.0 }
            group.leave()
        }

        group.notify(queue: .main) {
            // If nothing was found at all, return nil so caller can ignore.
            if snap.ageYears == nil, snap.biologicalSex == nil, snap.heightCm == nil, snap.weightKg == nil {
                completion(nil)
            } else {
                completion(snap)
            }
        }
    }

    private func latestSample(for type: HKQuantityType, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            guard let q = samples?.first as? HKQuantitySample else { completion(nil); return }
            completion(q.quantity.doubleValue(for: unit))
        }
        store.execute(q)
    }
}

