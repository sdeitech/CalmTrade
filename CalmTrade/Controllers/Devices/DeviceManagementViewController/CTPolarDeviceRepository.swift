//
//  CTPolarDeviceRepository.swift
//  CalmTrade
//

import Foundation
import UIKit
import UserNotifications


extension Notification.Name {
    /// Posted whenever a device snapshot (battery/firmware/charging or settings) changes.
     public static let ctDeviceSnapshotDidChange = Notification.Name("ct.device.snapshotDidChange")
}

/// Adapts PolarManager + DeviceManager into the CTDeviceRepository protocol
final class CTPolarDeviceRepository: CTDeviceRepository {
    static let shared = CTPolarDeviceRepository()

    private let pm = PolarManager.shared
    private let ud = UserDefaults.standard
    private var cache: [String: CTDeviceSummary] = [:]
    private var lastSnapshotPost = Date()
    private func postSnapshotChange() {
        let now = Date()
        guard now.timeIntervalSince(lastSnapshotPost) > 1.0 else { return }
        lastSnapshotPost = now
        NotificationCenter.default.post(name: .ctDeviceSnapshotDidChange, object: nil)
    }
    private let lowBatteryThreshold = 20
    private let recoveryThreshold = 25
    private let notificationCooldown: TimeInterval = 60 * 15 // 15 minutes

    private init() {
        // Keep device list warm as discovery/connection changes
        pm.onDevicesUpdated = { [weak self] devices in
            guard let self else { return }
            devices.forEach { self.ensureCacheEntry(for: $0) }
            self.postSnapshotChange()
        }
        _ = pm.addConnectionObserver { [weak self] state in
            guard let self else { return }
            switch state {
            case .connected(let dev):
                self.ensureCacheEntry(for: dev)
                // Kick a fresh snapshot to populate firmware/battery immediately.
                self.pm.refreshSnapshot()
                self.postSnapshotChange()
            default:
                break
            }
        }

        // Full snapshot from your PolarManager (recommended)
        pm.onSnapshot = { [weak self] snap in
            guard let self else { return }
            let key = snap.id
            if var s = self.cache[key] {
                s.firmwareVersion = snap.firmware
                s.batteryPercent  = snap.batteryLevel.map { Int($0) }
                s.isCharging      = snap.charging
                s.lastSyncedAt    = snap.timestamp
                self.cache[key]   = s
            } else {
                let type: CTDeviceType = snap.name.lowercased().contains("h10") ? .h10 : .polar360
                let img = (type == .h10)
                    ? (UIImage(named: "Polar H10") ?? UIImage(systemName: "waveform.path.ecg"))
                    : (UIImage(named: "polar360") ?? UIImage(systemName: "applewatch"))
                self.cache[key] = CTDeviceSummary(
                    id: CTDeviceID(snap.id),
                    name: snap.name,
                    type: type,
                    image: img,
                    firmwareVersion: snap.firmware,
                    hasFirmwareUpdateAvailable: false,
                    lastSyncedAt: snap.timestamp,
                    batteryPercent: snap.batteryLevel.map { Int($0) },
                    isCharging: snap.charging,
                    wrist: type == .polar360 ? self.appWrist(for: snap.id) : nil,
                    batteryNotificationEnabled: self.appBatteryNotif(for: snap.id)
                )
            }
            self.postSnapshotChange()
        }

        // Lean battery callback (optional if you also emit a full onSnapshot)
        pm.onBatteryUpdate = { [weak self] id, level, charging in
            guard let self else { return }

            let intLevel = Int(level)
            let isCharging = charging ?? false

            // Update cache (existing behavior)
            if var s = self.cache[id] {
                s.batteryPercent = intLevel
                s.isCharging     = isCharging
                s.lastSyncedAt   = Date()
                self.cache[id]   = s
                self.postSnapshotChange()
            }

            self.handleBatteryLifecycle(
                id: id,
                level: intLevel,
                charging: isCharging
            )
        }
    }

    // MARK: - Helpers

    private func ensureCacheEntry(for dev: ScannedPolarDevice) {
        let type: CTDeviceType = dev.name.lowercased().contains("h10") ? .h10 : .polar360
        let img = (type == .h10)
            ? (UIImage(named: "polar_h10") ?? UIImage(systemName: "waveform.path.ecg"))
            : (UIImage(named: "polar360") ?? UIImage(systemName: "applewatch"))

        if cache[dev.id] == nil {
            cache[dev.id] = CTDeviceSummary(
                id: .init(dev.id),
                name: dev.name,
                type: type,
                image: img,
                firmwareVersion: nil,
                hasFirmwareUpdateAvailable: false,
                lastSyncedAt: nil,
                batteryPercent: nil,
                isCharging: nil,
                wrist: type == .polar360 ? appWrist(for: dev.id) : nil,
                batteryNotificationEnabled: appBatteryNotif(for: dev.id)
            )
        }
    }

    private func appBatteryNotif(for id: String) -> Bool {
        ud.bool(forKey: "ct.dev.\(id).batteryNotif")
    }
    private func key(_ id: String, _ suffix: String) -> String {
        "ct.dev.\(id).\(suffix)"
    }
    private func setAppBatteryNotif(_ enabled: Bool, id: String) {
        ud.set(enabled, forKey: "ct.dev.\(id).batteryNotif")
    }
    private func appWrist(for id: String) -> CTWristPlacement {
        ud.string(forKey: "ct.dev.\(id).wrist") == "right" ? .right : .left
    }
    private func setAppWrist(_ wrist: CTWristPlacement, id: String) {
        ud.set(wrist == .right ? "right" : "left", forKey: "ct.dev.\(id).wrist")
    }

    // MARK: - CTDeviceRepository

    func fetchConnectedDevices() async throws -> [CTDeviceSummary] {
        var results: [CTDeviceSummary] = []
        if let dev = pm.connectedDevice {
            ensureCacheEntry(for: dev)
            if let s = cache[dev.id] { results.append(s) }
        }
        results.append(contentsOf: pm.discoveredDevices.compactMap { cache[$0.id] })
        return results
    }

    func getActiveDeviceID() -> CTDeviceID? {
        if let dev = pm.connectedDevice { return CTDeviceID(dev.id) }
        if let raw = ud.string(forKey: "ct.dev.active") { return CTDeviceID(raw) }
        return nil
    }

    func setActiveDevice(id: CTDeviceID) {
        if let dev = pm.discoveredDevices.first(where: { $0.id == id.raw }) {
            pm.connect(to: dev)
            ud.set(id.raw, forKey: "ct.dev.active")
            // Pull latest firmware/battery as soon as we switch
            pm.refreshSnapshot()
        }
    }

    func setBatteryNotification(_ enabled: Bool, for id: CTDeviceID) async throws {
        setAppBatteryNotif(enabled, id: id.raw)
        // keep cache in sync so UI doesn't "snap back"
        if var s = cache[id.raw] {
            s.batteryNotificationEnabled = enabled
            cache[id.raw] = s
        }
        self.postSnapshotChange()
    }

    func setWristPlacement(_ wrist: CTWristPlacement, for id: CTDeviceID) async throws {
        setAppWrist(wrist, id: id.raw)
        if var s = cache[id.raw] { s.wrist = wrist; cache[id.raw] = s }
        self.postSnapshotChange()
    }

    /// Real sync: triggers PolarManager's ordered offline pipeline (and then refreshes snapshot for UI)
    func syncNow(id: CTDeviceID) async throws {
        guard let dev = pm.connectedDevice, dev.id == id.raw else {
            throw NSError(domain: "CTPolarDeviceRepository", code: -20,
                          userInfo: [NSLocalizedDescriptionKey: "Device not connected"])
        }
        pm.syncNow()
        // Opportunistic snapshot refresh so UI reflects latest battery/firmware time
        pm.refreshSnapshot()
    }

    // Turn off via PolarManager.turnOff (supported devices only).
    func powerOff(id: CTDeviceID) async throws {
        guard let dev = pm.connectedDevice, dev.id == id.raw else {
            throw NSError(domain: "CTPolarDeviceRepository", code: -21,
                          userInfo: [NSLocalizedDescriptionKey: "Device not connected"])
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            pm.turnOff { result in
                switch result {
                case .success:
                    cont.resume(returning: ())          // ✅ important
                case .failure(let err):
                    cont.resume(throwing: err)
                }
            }
        }
    }

    /// Factory reset via PolarManager.factoryReset (supported devices only).
    func factoryReset(id: CTDeviceID) async throws {
        guard let dev = pm.connectedDevice, dev.id == id.raw else {
            throw NSError(domain: "CTPolarDeviceRepository", code: -22,
                          userInfo: [NSLocalizedDescriptionKey: "Device not connected"])
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            pm.factoryReset(preservePairing: true) { result in
                switch result {
                case .success:
                    cont.resume(returning: ())          // ✅ important
                case .failure(let err):
                    cont.resume(throwing: err)
                }
            }
        }
    }
    
    private func handleBatteryLifecycle(
        id: String,
        level: Int,
        charging: Bool
    ) {
        guard appBatteryNotif(for: id) else { return }

        let now = Date()

        let lowNotifiedKey = key(id, "lowNotified")
        let chargingStartedKey = key(id, "chargingStartedNotified")
        let chargingCompletedKey = key(id, "chargingCompletedNotified")
        let lastChargingStateKey = key(id, "lastChargingState")
        let lastNotificationDateKey = key(id, "lastNotificationDate")

        let previousCharging = UserDefaults.standard.bool(forKey: lastChargingStateKey)

        // Cooldown guard
        if let lastDate = UserDefaults.standard.object(forKey: lastNotificationDateKey) as? Date {
            if now.timeIntervalSince(lastDate) < notificationCooldown {
                UserDefaults.standard.set(charging, forKey: lastChargingStateKey)
                return
            }
        }

        // ---------------------------
        // 🔻 LOW BATTERY
        // ---------------------------
        if !charging && level <= lowBatteryThreshold {
            let already = UserDefaults.standard.bool(forKey: lowNotifiedKey)
            if !already {
                triggerNotification(
                    title: "Low Battery",
                    body: "Your Polar device battery is at \(level)%."
                )
                UserDefaults.standard.set(true, forKey: lowNotifiedKey)
                UserDefaults.standard.set(now, forKey: lastNotificationDateKey)
            }
        }

        // Reset low battery if recovered
        if level >= recoveryThreshold {
            UserDefaults.standard.set(false, forKey: lowNotifiedKey)
        }

        // ---------------------------
        // ⚡ CHARGING STARTED
        // ---------------------------
        if charging && !previousCharging {
            let already = UserDefaults.standard.bool(forKey: chargingStartedKey)
            if !already {
                triggerNotification(
                    title: "Charging Started",
                    body: "Your Polar device is now charging."
                )
                UserDefaults.standard.set(true, forKey: chargingStartedKey)
                UserDefaults.standard.set(false, forKey: chargingCompletedKey)
                UserDefaults.standard.set(now, forKey: lastNotificationDateKey)
            }
        }

        // Reset charging-start flag if unplugged
        if !charging {
            UserDefaults.standard.set(false, forKey: chargingStartedKey)
        }

        // ---------------------------
        // 🔋 CHARGING COMPLETED
        // ---------------------------
        if previousCharging && !charging && level == 100 {
            let already = UserDefaults.standard.bool(forKey: chargingCompletedKey)
            if !already {
                triggerNotification(
                    title: "Charging Complete",
                    body: "Your Polar device is fully charged."
                )
                UserDefaults.standard.set(true, forKey: chargingCompletedKey)
                UserDefaults.standard.set(now, forKey: lastNotificationDateKey)
            }
        }

        // Store latest charging state
        UserDefaults.standard.set(charging, forKey: lastChargingStateKey)
    }
    
    private func triggerNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - New Additions for Storage + Timezone

extension CTPolarDeviceRepository {

    // MARK: - FETCH STORAGE
    func fetchStorage(id: CTDeviceID) async throws -> (used: Int, total: Int) {
        try await withCheckedThrowingContinuation { cont in
            pm.fetchStorageStatus(id.raw) { result in
                switch result {
                case .success(let tuple):
                    cont.resume(returning: tuple)
                case .failure(let err):
                    cont.resume(throwing: err)
                }
            }
        }
    }

    // MARK: - FETCH DEVICE TIME
    func fetchDeviceTime(id: CTDeviceID) async throws -> Date {
        try await withCheckedThrowingContinuation { cont in
            pm.fetchDeviceTime(id.raw) { result in
                switch result {
                case .success(let date):
                    cont.resume(returning: date)
                case .failure(let err):
                    cont.resume(throwing: err)
                }
            }
        }
    }

    // MARK: - SET DEVICE TIME TO LOCAL TIME
    func setDeviceTimeToLocal(id: CTDeviceID) async throws {
        pm.setLocalTimeNow(id.raw)
    }
}
