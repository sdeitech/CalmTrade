//
//  AccountDetailsViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 29/10/25.
//

import Foundation

// MARK: - ViewModel

final class AccountDetailsViewModel {

    // MARK: - Dependencies
    private let profileService = ProfileService()
    private var device: Polar360MetricsProvider
    private let accessToken: String

    // MARK: - Outputs
    var onLoading: ((Bool) -> Void)?
    var onUI: ((AccountDetailsUI) -> Void)?
    var onError: ((String) -> Void)?

    // MARK: - State
    private var snapshot: Polar360Snapshot
    private var cancellable: Any?

    // MARK: - Init
    init(accessToken: String,
         device: Polar360MetricsProvider = Polar360MetricsCenter.shared) {

        self.accessToken = accessToken
        self.device = device
        self.snapshot = device.currentSnapshot

        // Observe Polar changes
        self.device.onSnapshot = { [weak self] snap in
            self?.snapshot = snap
            self?.emitUI()
        }

        // Observe global user changes
        cancellable = NotificationCenter.default.addObserver(
            forName: .userAccountDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.emitUI()
        }
    }

    deinit {
        if let c = cancellable {
            NotificationCenter.default.removeObserver(c)
        }
    }

    // MARK: - Load / Refresh
    func load() {
        onLoading?(true)

        profileService.refreshProfile(accessToken: accessToken) { [weak self] _, err in
            guard let self else { return }
            self.onLoading?(false)

            if let err {
                self.onError?(err)
            } else {
                self.emitUI()
            }
        }
    }

    // MARK: - UI Composition
    private func emitUI() {
        guard let user = SessionManager.shared.current else { return }

        let age = snapshot.ageYears
        let ageText = age.map { "\($0) years" } ?? "—"

        let maxHR: Int = {
            if let m = snapshot.maxHR { return m }
            if let a = age { return max(80, 220 - a) }
            return 180
        }()

        let ui = AccountDetailsUI(
            displayName: user.displayName.nilIfEmpty ?? "—",
            email: user.email.nilIfEmpty ?? "—",
            ageText: ageText,
            sexText: snapshot.biologicalSex?.capitalized ?? "—",
            rhrText: "\(snapshot.restingHR ?? 60) bpm",
            maxHRText: "\(maxHR) bpm",
            userId: user.id,
            createdOn: user.createdAt.map(Self.formatDate) ?? "—",
            lastSignIn: user.lastLoginAt.map(Self.formatDateTime) ?? "—",
            heightText: snapshot.heightCm.map(Self.formatHeightImperial) ?? "—",
            weightText: snapshot.weightKg.map(Self.formatWeightLbs) ?? "—"
        )

        onUI?(ui)
    }

    // MARK: - Formatters
    private static func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: d)
    }

    private static func formatDateTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f.string(from: d)
    }

    private static func formatWeightLbs(_ kg: Double) -> String {
        String(format: "%.1f lbs", kg * 2.20462)
    }

    private static func formatHeightImperial(_ cm: Double) -> String {
        let totalInches = cm / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(round(totalInches.truncatingRemainder(dividingBy: 12)))
        return "\(feet) ft \(inches) in"
    }
}


private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Polar 360 metrics interface

// ---- Fix 2: keep protocol/class as internal (remove `public`) to avoid
//             "public method with internal type" errors. ----

protocol Polar360MetricsProvider {
    /// Latest merged snapshot: prefers FTU → then HK → else empty
    var currentSnapshot: Polar360Snapshot { get }

    /// Called whenever a new (merged) snapshot is available
    var onSnapshot: ((Polar360Snapshot) -> Void)? { get set }
}

// MARK: - Center with precedence: FTU > HealthKit

final class Polar360MetricsCenter: Polar360MetricsProvider {
    // ---- Fix 3: `shared` is internal; avoid default-arg references by using the
    //             convenience init in the VM instead. ----
    static let shared = Polar360MetricsCenter()
    private init() {}

    // Sources
    private var ftuSnapshot: Polar360Snapshot?    // set by your FTU flow
    private var hkSnapshot: Polar360Snapshot?     // populated from HealthKit

    // Listener
    var onSnapshot: ((Polar360Snapshot) -> Void)?

    // Public merged view
    var currentSnapshot: Polar360Snapshot {
        return ftuSnapshot ?? hkSnapshot ?? .empty
    }

    // MARK: - Source updates

    /// Call once (e.g., app start or before showing Account Details) to seed from HealthKit.
    // ---- Fix 4: remove `public` and remove default arg; provide a no-arg overload. ----
    func startHealthKitBootstrap(reader: HealthProfileReader) {
        reader.requestAndFetch { [weak self] snap in
            guard let self = self else { return }
            self.hkSnapshot = snap
            self.publishCombined()
        }
    }

    /// Convenience overload that uses the shared HK reader without default-arg pitfalls.
    func startHealthKitBootstrap() {
        startHealthKitBootstrap(reader: .shared)
    }

    /// Call this when your local FTU completes (DOB/sex/height/weight known in-app).
    func setLocalFTUSnapshot(_ snap: Polar360Snapshot) {
        self.ftuSnapshot = snap
        self.publishCombined()
    }

    /// If user edits FTU fields later, call again with updated snapshot.
    func updateLocalFTU(_ transform: (inout Polar360Snapshot?) -> Void) {
        transform(&ftuSnapshot)
        publishCombined()
    }

    // MARK: - Notify

    private func publishCombined() {
        let merged = currentSnapshot
        onSnapshot?(merged)
    }
}
