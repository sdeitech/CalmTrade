//
//  DeviceModels.swift
//  CalmTrade
//

import UIKit

// MARK: - Types

enum CTDeviceType: String, Codable {
    case polar360 = "Polar 360"
    case h10      = "Polar H10"
}

enum CTWristPlacement: String, Codable {
    case left  = "Left Wrist"
    case right = "Right Wrist"
}

struct CTDeviceID: Hashable, Codable {
    let raw: String
    init(_ raw: String) { self.raw = raw }
}

/// Snapshot for one device that the screen binds to.
/// (Not Codable because of UIImage; Equatable is enough for UI diffing.)
struct CTDeviceSummary: Equatable {
    let id: CTDeviceID
    let name: String
    let type: CTDeviceType
    let image: UIImage?

    // Info block (mutable because live updates arrive after connect)
    var firmwareVersion: String?
    let hasFirmwareUpdateAvailable: Bool
    var lastSyncedAt: Date?
    var batteryPercent: Int?          // 0...100
    var isCharging: Bool?

    // Settings (app-side for 360)
    var wrist: CTWristPlacement?
    var batteryNotificationEnabled: Bool

    // Capabilities (truthful to Polar SDK: power off/reset not available)
    var canToggleBatteryNotifications: Bool { type == .polar360 }
    var canChooseWristPlacement: Bool { type == .polar360 }
    var canSync: Bool { true }                 // “Sync” = refresh snapshot
    var canPowerOff: Bool { false }
    var canFactoryReset: Bool { false }
}

protocol CTDeviceRepository {
    // Read
    func fetchConnectedDevices() async throws -> [CTDeviceSummary]
    func getActiveDeviceID() -> CTDeviceID?

    // Mutations
    func setActiveDevice(id: CTDeviceID)
    func setBatteryNotification(_ enabled: Bool, for id: CTDeviceID) async throws
    func setWristPlacement(_ wrist: CTWristPlacement, for id: CTDeviceID) async throws

    func syncNow(id: CTDeviceID) async throws
    func powerOff(id: CTDeviceID) async throws
    func factoryReset(id: CTDeviceID) async throws
    
    func fetchStorage(id: CTDeviceID) async throws -> (used: Int, total: Int)
    func fetchDeviceTime(id: CTDeviceID) async throws -> Date
    func setDeviceTimeToLocal(id: CTDeviceID) async throws
}
