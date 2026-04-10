//
//  DeviceManagementViewModel.swift
//  CalmTrade
//

import Foundation
import PolarBleSdk


@MainActor
protocol DeviceManagementViewModelDelegate: AnyObject {
    func vmDidUpdateCurrentDevice(_ vm: DeviceManagementViewModel)
    func vmDidStartLongOperation(_ vm: DeviceManagementViewModel, title: String)
    func vmDidEndLongOperation(_ vm: DeviceManagementViewModel, successMessage: String?)
    func vmDidError(_ vm: DeviceManagementViewModel, message: String)
}

final class DeviceManagementViewModel {
    // Inject for testability
    private let repo: CTDeviceRepository
    weak var delegate: DeviceManagementViewModelDelegate?
    private var isLoading = false
    
    @Published private(set) var storageUsed: Int?
    @Published private(set) var storageTotal: Int?

    @Published private(set) var deviceTime: Date?
    @Published private(set) var timezoneMismatch: Bool = false

    
    // Data
    private(set) var devices: [CTDeviceSummary] = [] {
        didSet {
            NSLog("[DMVM] devices updated: count \(devices.count) (old \(oldValue.count))")
        }
    }
    private(set) var currentIndex: Int = 0 {
        didSet {
            NSLog("[DMVM] currentIndex changed: \(oldValue) → \(currentIndex)")
        }
    }
    
    private var obsToken: NSObjectProtocol?
    
    // Firmware (added; non-breaking)
    private var fwCheckToken: NSObjectProtocol?
    private var fwProgressToken: NSObjectProtocol?
    private(set) var isFwAvailable: Bool = false {
        didSet { NSLog("[DMVM] isFwAvailable: \(oldValue) → \(isFwAvailable)") }
    }
    private(set) var isFwUpdating: Bool = false {
        didSet { NSLog("[DMVM] isFwUpdating: \(oldValue) → \(isFwUpdating)") }
    }
    
    private var latestSnapshotFirmware: [String: String] = [:]
    private var lastFWCheck = Date.distantPast
    
    var current: CTDeviceSummary? {
        guard devices.indices.contains(currentIndex) else {
            NSLog("[DMVM] current requested but index \(currentIndex) out of range (0..\((devices.count > 0 ? devices.count - 1 : -1)))")
            return nil
        }
        return devices[currentIndex]
    }
    
    // MARK: - Init
    init(repo: CTDeviceRepository = CTPolarDeviceRepository.shared) {
        self.repo = repo
        NSLog("[DMVM] init; installing .ctDeviceSnapshotDidChange observer")
        
        // Live push from repository (battery %, charging, firmware, settings)
        obsToken = NotificationCenter.default.addObserver(
            forName: .ctDeviceSnapshotDidChange, object: nil, queue: .main
        ) { [weak self] note in
            guard let self else { return }
            NSLog("[DMVM] 🔔 Received .ctDeviceSnapshotDidChange note userInfo=\(String(describing: note.userInfo))")

            if let id = note.userInfo?["id"] as? String,
               let fw = note.userInfo?["firmware"] as? String,
               !fw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.latestSnapshotFirmware[id] = fw
                NSLog("[DMVM] cached firmware for \(id): \(fw)")
            }

            // ⛔️ CRITICAL: avoid re-entrant load() while an OTA is running
            guard !self.isFwUpdating else {
                NSLog("[DMVM] skip load(): firmware update in progress")
                return
            }
            Task { await self.load() }
        }
    }
    
    deinit {
        NSLog("[DMVM] deinit; removing observers")
        if let t = obsToken { NotificationCenter.default.removeObserver(t) }
        if let t = fwCheckToken { NotificationCenter.default.removeObserver(t) }
        if let t = fwProgressToken { NotificationCenter.default.removeObserver(t) }
    }
    
    // MARK: - Loading
    @MainActor
    func load() async {
        guard !isLoading else {
            NSLog("[DMVM] load() skipped: already running")
            return
        }
        isLoading = true
        defer { isLoading = false }
        NSLog("[DMVM] ▶️ load() begin")
        do {
            let list = try await repo.fetchConnectedDevices()
            NSLog("[DMVM] fetchConnectedDevices() returned \(list.count) devices")
            self.devices = list
            
            // Active device selection
            if let active = repo.getActiveDeviceID(),
               let idx = list.firstIndex(where: { $0.id == active }) {
                NSLog("[DMVM] active device id=\(active.raw) found at index \(idx)")
                self.currentIndex = idx
            } else {
                self.currentIndex = 0
                if let first = list.first {
                    NSLog("[DMVM] no active device in repo; selecting first id=\(first.id.raw)")
                    repo.setActiveDevice(id: first.id)
                } else {
                    NSLog("[DMVM] no devices connected; nothing to select")
                }
            }
            
            NSLog("[DMVM] delegate.vmDidUpdateCurrentDevice()")
            await MainActor.run {
                self.delegate?.vmDidUpdateCurrentDevice(self)
            }
            
            // Kick a non-forced FW check (safe no-op if unsupported/not connected)
            if !isFwUpdating {
                NSLog("[DMVM] calling checkFirmwareNonForced() post-load")
                await checkFirmwareNonForced()
            } else {
                NSLog("[DMVM] skip checkFirmwareNonForced(): update in progress")
            }
            
            NSLog("[DMVM] ▶️ load() end (success)")
        } catch {
            NSLog("[DMVM] ❌ load() error: \(error.localizedDescription)")
            delegate?.vmDidError(self, message: "Failed to load devices.")
        }
    }
    
    // MARK: - Paging
    func goNext() async {
        NSLog("[DMVM] ▶️ goNext() (isFwUpdating=\(isFwUpdating), devices.count=\(devices.count))")
        guard !devices.isEmpty else { NSLog("[DMVM] goNext aborted: no devices"); return }
        guard !isFwUpdating else { NSLog("[DMVM] goNext aborted: firmware updating"); return }
        currentIndex = (currentIndex + 1) % devices.count
        let id = devices[currentIndex].id
        NSLog("[DMVM] setActiveDevice(id=\(id.raw))")
        repo.setActiveDevice(id: id)
        NSLog("[DMVM] delegate.vmDidUpdateCurrentDevice()")
        await MainActor.run {
            self.delegate?.vmDidUpdateCurrentDevice(self)
        }
        Task {
            NSLog("[DMVM] post-goNext checkFirmwareNonForced()")
            await safeFirmwareCheck()
        }
    }
    
    func goPrev() async {
        NSLog("[DMVM] ▶️ goPrev() (isFwUpdating=\(isFwUpdating), devices.count=\(devices.count))")
        guard !devices.isEmpty else { NSLog("[DMVM] goPrev aborted: no devices"); return }
        guard !isFwUpdating else { NSLog("[DMVM] goPrev aborted: firmware updating"); return }
        currentIndex = (currentIndex - 1 + devices.count) % devices.count
        let id = devices[currentIndex].id
        NSLog("[DMVM] setActiveDevice(id=\(id.raw))")
        repo.setActiveDevice(id: id)
        NSLog("[DMVM] delegate.vmDidUpdateCurrentDevice()")
        await MainActor.run {
            self.delegate?.vmDidUpdateCurrentDevice(self)
        }
        Task {
            NSLog("[DMVM] post-goPrev checkFirmwareNonForced()")
            await safeFirmwareCheck()
        }
    }
    
    // MARK: - Mutations / Actions
    @MainActor
    func toggleBatteryNotification(_ enabled: Bool) async {
        NSLog("[DMVM] ▶️ toggleBatteryNotification(enabled=\(enabled))")
        guard let d = current, d.canToggleBatteryNotifications else {
            NSLog("[DMVM] toggleBatteryNotification aborted: no current or unsupported")
            return
        }
        delegate?.vmDidStartLongOperation(self, title: "Updating…")
        do {
            NSLog("[DMVM] repo.setBatteryNotification(\(enabled), id=\(d.id.raw))")
            try await repo.setBatteryNotification(enabled, for: d.id)
            NSLog("[DMVM] ✅ battery notification set OK")
            delegate?.vmDidEndLongOperation(self, successMessage: "Battery notifications \(enabled ? "enabled" : "disabled").")
        } catch {
            NSLog("[DMVM] ❌ setBatteryNotification error: \(error.localizedDescription)")
            delegate?.vmDidError(self, message: "Couldn't update battery notifications.")
        }
    }
    
    @MainActor
    func setWrist(_ wrist: CTWristPlacement) async {
        NSLog("[DMVM] ▶️ setWrist(\(wrist))")
        guard let d = current, d.canChooseWristPlacement else {
            NSLog("[DMVM] setWrist aborted: no current or unsupported")
            return
        }
        delegate?.vmDidStartLongOperation(self, title: "Saving…")
        do {
            NSLog("[DMVM] repo.setWristPlacement(\(wrist), id=\(d.id.raw))")
            try await repo.setWristPlacement(wrist, for: d.id)
            NSLog("[DMVM] ✅ setWristPlacement OK")
            // No explicit success toast needed per existing code
        } catch {
            NSLog("[DMVM] ❌ setWristPlacement error: \(error.localizedDescription)")
            delegate?.vmDidError(self, message: "Couldn't save wrist placement.")
        }
    }
    
    @MainActor
    func sync() async {
        NSLog("[DMVM] ▶️ sync()")
        guard let d = current, d.canSync else {
            NSLog("[DMVM] sync aborted: no current or unsupported")
            return
        }
        delegate?.vmDidStartLongOperation(self, title: "Syncing…")
        do {
            NSLog("[DMVM] repo.syncNow(id=\(d.id.raw))")
            try await repo.syncNow(id: d.id)
            NSLog("[DMVM] ✅ syncNow OK")
            delegate?.vmDidEndLongOperation(self, successMessage: "Sync complete.")
        } catch {
            NSLog("[DMVM] ❌ sync error: \(error.localizedDescription)")
            delegate?.vmDidError(self, message: "Sync failed: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func powerOff() async {
        guard let d = current else { return }
        delegate?.vmDidStartLongOperation(self, title: "Powering off…")
        do { try await repo.powerOff(id: d.id); delegate?.vmDidEndLongOperation(self, successMessage: "Device turned off.") }
        catch { delegate?.vmDidError(self, message: "Power off failed: \(error.localizedDescription)") }
    }

    @MainActor
    func factoryReset() async {
        guard let d = current else { return }
        delegate?.vmDidStartLongOperation(self, title: "Resetting…")
        do { try await repo.factoryReset(id: d.id); delegate?.vmDidEndLongOperation(self, successMessage: "Factory reset complete.") }
        catch { delegate?.vmDidError(self, message: "Factory reset failed: \(error.localizedDescription)") }
    }
    
    // MARK: - Firmware (non-forced, additive)
    
    /// Safe to call anytime (on load, after paging, pull-to-refresh, etc.)
    @MainActor
    func checkFirmwareNonForced() async {
        guard !isFwUpdating else {
            NSLog("[DMVM] checkFirmwareNonForced() blocked: update in progress")
            return
        }
        NSLog("[DMVM] ▶️ checkFirmwareNonForced() setup observer & request")
        // Reinstall observer (single-shot style is fine; we clean old one)
        if let t = fwCheckToken {
            NSLog("[DMVM] removing previous fwCheckToken")
            NotificationCenter.default.removeObserver(t)
        }
        fwCheckToken = NotificationCenter.default.addObserver(forName: .ctFwCheck, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            NSLog("[DMVM] 🔔 .ctFwCheck received userInfo=\(String(describing: note.userInfo))")
            if let s = note.userInfo?["status"] as? CheckFirmwareUpdateStatus {
                switch s {
                case .checkFwUpdateAvailable:
                    NSLog("[DMVM] firmware update AVAILABLE")
                    self.isFwAvailable = true
                case .checkFwUpdateNotAvailable:
                    NSLog("[DMVM] firmware update NOT available")
                    self.isFwAvailable = false
                case .checkFwUpdateFailed(let details):
                    NSLog("[DMVM] firmware check FAILED: \(details)")
                    self.isFwAvailable = false
                @unknown default:
                    NSLog("[DMVM] firmware check unknown status → treating as not available")
                    self.isFwAvailable = false
                }
                NSLog("[DMVM] delegate.vmDidUpdateCurrentDevice() after fw check")
                self.delegate?.vmDidUpdateCurrentDevice(self)
            } else {
                NSLog("[DMVM] ⚠️ .ctFwCheck had no parsable 'status'")
            }
        }
        // Ask PolarManager to perform non-forced check (will no-op if unsupported)
        NSLog("[DMVM] PolarManager.shared.checkFirmwareUpdateNonForced(minBatteryPercent: 30)")
        PolarManager.shared.checkFirmwareUpdateNonForced(minBatteryPercent: 30)
    }
    
    @MainActor
    func safeFirmwareCheck() async {
        guard Date().timeIntervalSince(lastFWCheck) > 10 else { return }
        lastFWCheck = Date()
        await checkFirmwareNonForced()
    }
    
    /// Call after the user confirms “Update now”.
    @MainActor
    func startFirmwareUpdate() async {
        NSLog("[DMVM] ▶️ startFirmwareUpdate()")
        guard !isFwUpdating else {
            NSLog("[DMVM] startFirmwareUpdate aborted: already updating")
            return
        }
        isFwUpdating = true
        delegate?.vmDidStartLongOperation(self, title: "Updating firmware…")
        
        // Replace previous progress observer if any
        if let t = fwProgressToken {
            NSLog("[DMVM] removing previous fwProgressToken")
            NotificationCenter.default.removeObserver(t)
        }
        fwProgressToken = NotificationCenter.default.addObserver(forName: .ctFwProgress, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            NSLog("[DMVM] 🔔 .ctFwProgress received userInfo=\(String(describing: note.userInfo))")
            
            if let p = note.userInfo?["progress"] as? FirmwareProgress {
                let stageText = p.detail != nil ? "\(p.stage) — \(p.detail!)" : p.stage
                let latestFwStageText = p.fraction != nil ? "\(stageText) (\(Int((p.fraction ?? 0)*100))%)" : stageText

                if p.stage == "Completed" {
                    self.isFwUpdating = false
                    self.isFwAvailable = false
                    self.delegate?.vmDidEndLongOperation(self, successMessage: "Firmware updated.")
                    Task { await self.load() }
                    return
                }

                if p.stage == "Not available" {
                    self.isFwUpdating = false
                    self.isFwAvailable = false
                    self.delegate?.vmDidEndLongOperation(self, successMessage: nil)
                    // Refresh the availability text so the label flips back to “No updates”
                    Task { await self.checkFirmwareNonForced() }
                    return
                }

                if p.stage == "Error" {
                    self.isFwUpdating = false
                    self.delegate?.vmDidError(self, message: p.detail ?? "Firmware update failed.")
                    return
                }

                // Otherwise keep spinner + evolving title:
                self.delegate?.vmDidStartLongOperation(self, title: stageText)
            } else if let err = note.userInfo?["error"] as? Error {
                self.isFwUpdating = false
                NSLog("[DMVM] ❌ firmware update ERROR: \(err.localizedDescription)")
                self.delegate?.vmDidError(self, message: "Firmware update failed: \(err.localizedDescription)")
            } else {
                NSLog("[DMVM] ⚠️ .ctFwProgress had neither 'progress' nor 'error'")
            }
        }
        
        NSLog("[DMVM] PolarManager.shared.beginFirmwareUpdate()")
        PolarManager.shared.beginFirmwareUpdate()
    }
    
    // MARK: - Formatting (for VC)
    func deviceIdText(_ d: CTDeviceSummary) -> String {
        let s = "ID: \(d.id.raw)"
        NSLog("[DMVM] deviceIdText(\(d.name)) → \(s)")
        return s
    }
    
    func firmwareText(_ d: CTDeviceSummary) -> String {
        // 1) Prefer repo value if present
        if let ver = d.firmwareVersion, !ver.isEmpty {
            NSLog("[DMVM] firmwareText(\(d.name)) → Firmware: \(ver) [repo]")
            return "Firmware: \(ver)"
        }
        // 2) Else prefer the live snapshot cache from PolarManager
        if let snapFW = latestSnapshotFirmware[d.id.raw], !snapFW.isEmpty {
            NSLog("[DMVM] firmwareText(\(d.name)) → Firmware: \(snapFW) [snapshot]")
            return "Firmware: \(snapFW)"
        }
        // 3) Fallback (no special-case text for 360 anymore)
        let s = "Firmware: —"
        NSLog("[DMVM] firmwareText(\(d.name)) → \(s)")
        return s
    }
    
    /// Prefer live flag if we have it; fall back to repository summary
    func updateAvailabilityText(_ d: CTDeviceSummary) -> String {
        let s = isFwAvailable ? "Update available" : (d.hasFirmwareUpdateAvailable ? "Update available" : "No updates")
        NSLog("[DMVM] updateAvailabilityText(\(d.name)) → \(s) (isFwAvailable=\(isFwAvailable), repoFlag=\(d.hasFirmwareUpdateAvailable))")
        return s
    }
    
    func lastSyncedText(_ d: CTDeviceSummary) -> String {
        let s: String
        if let ts = d.lastSyncedAt {
            let df = DateFormatter(); df.dateFormat = "M/d/yy, h:mm a"
            s = "Last synced: \(df.string(from: ts))"
        } else {
            s = "Last synced: —"
        }
        NSLog("[DMVM] lastSyncedText(\(d.name)) → \(s)")
        return s
    }
    
    func chargingText(_ d: CTDeviceSummary) -> String {
        let s: String
        if let pct = d.batteryPercent {
            if d.isCharging == true {
                s = "Charging: \(pct)%"
            } else {
                s = "Battery: \(pct)%"
            }
        } else {
            s = "—"
        }
        NSLog("[DMVM] chargingText(\(d.name)) → \(s)")
        return s
    }
    
    @MainActor
    func loadStorage() async {
        guard let d = current else { return }

        do {
            let s = try await repo.fetchStorage(id: d.id)
            self.storageUsed = s.used
            self.storageTotal = s.total
            await MainActor.run {
                self.delegate?.vmDidUpdateCurrentDevice(self)
            }
        } catch {
            delegate?.vmDidError(self, message: "Failed to load storage information.")
        }
    }

    @MainActor
    func loadDeviceTime() async {
        guard let d = current else { return }

        do {
            let t = try await repo.fetchDeviceTime(id: d.id)
            self.deviceTime = t

            let deviceOffset = TimeZone.current.secondsFromGMT(for: t)
            let phoneOffset  = TimeZone.current.secondsFromGMT()

            self.timezoneMismatch = (deviceOffset != phoneOffset)
            await MainActor.run {
                self.delegate?.vmDidUpdateCurrentDevice(self)
            }
        } catch {
            delegate?.vmDidError(self, message: "Unable to read device time.")
        }
    }

    @MainActor
    func setDeviceTimeToLocal() async {
        guard let d = current else { return }

        delegate?.vmDidStartLongOperation(self, title: "Setting time…")

        do {
            try await repo.setDeviceTimeToLocal(id: d.id)
            delegate?.vmDidEndLongOperation(self, successMessage: "Device time updated.")
            await loadDeviceTime()
        } catch {
            delegate?.vmDidError(self, message: "Unable to update device time.")
        }
    }

}
