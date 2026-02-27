//
//  PolarConnectionViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/09/25.
//

import Foundation
import PolarBleSdk

final class PolarConnectionViewModel {
    
    // MARK: - Public state the VC reads
    private(set) var discoveredDevices: [ScannedPolarDevice] = [] {
        didSet { onDeviceListUpdated?() }
    }
    
    // MARK: - Callbacks expected by your VC
    var onDeviceListUpdated: (() -> Void)?
    var onStateChanged: ((String) -> Void)?
    var onConnectionSuccess: ((String) -> Void)?
    var onConnectionFailed: ((String) -> Void)?
    
    // Optional: firmware update events (hooked from PolarManager)
    var onFirmwareCheck: ((CheckFirmwareUpdateStatus) -> Void)?
    var onFirmwareStatus: ((FirmwareUpdateStatus) -> Void)?
    var onFirmwareError: ((Error) -> Void)?
    
    private var connectTimeout: Timer?
    
    // MARK: - Private
    private let polarManager = PolarManager.shared
    private var pendingConnectDeviceName: String?
    private func vlog(_ msg: String) { NSLog("PolarVM ▶︎ %@", msg) }
    var onFirstTimeUseNeeded: ((String) -> Void)?
    
    var onFtuProgress: ((String) -> Void)?
    var onFtuCompleted: (() -> Void)?
    var onFtuError: ((String) -> Void)?
    /// Called when FTU is already done
    var onFtuNotNeeded: (() -> Void)?
    
    
    // MARK: - Init
    init() {
        wireUpManager()
        vlog("init; wiring manager callbacks")
    }
    
    private func wireUpManager() {
        // Device discovery list
        polarManager.onDevicesUpdated = { [weak self] list in
            guard let self else { return }
            self.vlog("onDevicesUpdated: \(list.count) device(s)")
            // Keep a stable, alphabetized list for your table view
            self.discoveredDevices = list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            if self.discoveredDevices.isEmpty {
                self.onStateChanged?("Searching...")
            } else {
                self.onStateChanged?("Select a device to connect")
            }
        }
        
        // Connection state -> UI strings + success/failure callbacks
        polarManager.onConnectionStateChanged = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .disconnected:
                self.vlog("state = disconnected")
                DispatchQueue.main.async {
                    self.clearConnectTimeout()
                    self.onStateChanged?("Disconnected")
                    if let pending = self.pendingConnectDeviceName {
                        self.onConnectionFailed?("Failed to connect to \(pending)")
                        self.pendingConnectDeviceName = nil
                    }
                }
            case .connecting(let dev):
                self.vlog("state = connecting(\(dev.name)) [\(dev.id)]")
                DispatchQueue.main.async {
                    self.onStateChanged?("Connecting to \(dev.name)…")
                    self.startConnectTimeout()   // keep watchdog running
                }
            case .connected(let dev):
                self.vlog("state = connected(\(dev.name)) [\(dev.id)]")
                DispatchQueue.main.async {
                    self.clearConnectTimeout()
                    self.onStateChanged?("Connected to \(dev.name)")
                    self.onConnectionSuccess?(dev.name)
                    self.pendingConnectDeviceName = nil
                }
            }
        }
        
        polarManager.onFirstTimeUseNeeded = { [weak self] dev in
            self?.onFirstTimeUseNeeded?(dev.name)   // triggers SwiftUI FTU
        }
        
        polarManager.onFtuProgress = { [weak self] msg in
            self?.onFtuProgress?(msg)
        }
        polarManager.onFtuCompleted = { [weak self] in
            self?.onFtuCompleted?()
        }
        polarManager.onFtuError = { [weak self] err in
            self?.onFtuError?(err.localizedDescription)
        }
        
        // Firmware events (optional; your VC bindings will use these if you wired them)
        polarManager.onFwCheck = { [weak self] st in self?.vlog("FW check: \(st)"); self?.onFirmwareCheck?(st) }
        polarManager.onFwStatus = { [weak self] st in self?.vlog("FW status: \(st)"); self?.onFirmwareStatus?(st) }
        polarManager.onFwError  = { [weak self] er in self?.vlog("FW error: \(er)"); self?.onFirmwareError?(er) }
    }
    
    func checkFtuStatus() {
        guard let dev = polarManager.connectedDevice else { return }
        let name = dev.name.lowercased()
        let isWristLike = name.contains("360")
            || name.contains("verity")
            || name.contains("oh1")
            || name.contains("ignite")
            || name.contains("pacer")
            || name.contains("unite")
            || name.contains("vantage")
            || name.contains("grit")

        // FTU is for optical/wrist-like devices only.
        guard isWristLike else {
            onFtuNotNeeded?()
            return
        }

        Task {
            do {
                let done = try await polarManager.api.isFtuDone(dev.id).value
                if done {
                    onFtuNotNeeded?()
                } else {
                    onFirstTimeUseNeeded?(dev.name)
                }
            } catch {
                // Transient reconnect/BLE errors should not force FTU UI.
                onFtuNotNeeded?()
            }
        }
    }
    
    // MARK: - Commands used by the VC
    
    // Call this from VC after user taps "Continue"
    func startFirstTimeUse(config: PolarFirstTimeUseConfig, restartAfter: Bool = false) {
        polarManager.onFtuProgress = { [weak self] msg in self?.onFtuProgress?(msg) }
        polarManager.onFtuCompleted = { [weak self] in self?.onFtuCompleted?() }
        polarManager.onFtuError = { [weak self] err in self?.onFtuError?(err.localizedDescription) }
        polarManager.performFirstTimeUse(config: config, restartAfter: restartAfter)
    }
    
    // After a successful connect, kick the FTU evaluation:
    private func notifyConnected(_ dev: ScannedPolarDevice) {
        PolarManager.shared.evaluateFirstTimeUseIfNeeded(for: dev)
    }
    
    func startSearch() {
        vlog("startSearch()")
        onStateChanged?("Searching...")
        polarManager.startDeviceSearch()
    }
    
    func stopSearch() {
        vlog("stopSearch()")
        polarManager.stopDeviceSearch()
        if discoveredDevices.isEmpty {
            onStateChanged?("Stopped")
        }
    }
    
    func connect(at index: Int) {
        guard index >= 0, index < discoveredDevices.count else { return }
        let device = discoveredDevices[index]
        
        // ✅ If we're already connected to this device, don't try again.
        if let current = polarManager.connectedDevice, current.id == device.id {
            vlog("connect(at:) → already connected to \(device.name), short-circuiting")
            pendingConnectDeviceName = nil
            onStateChanged?("Connected to \(device.name)")
            onConnectionSuccess?(device.name)
            return
        }
        
        // If the SDK is already connecting to the same device, also short-circuit
        if let connecting = polarManager.connectingDevice, connecting.id == device.id {
            vlog("connect(at:) → already connecting to \(device.name), ignoring duplicate tap")
            // Optional: show a subtle hint instead of spinning forever
            onStateChanged?("Connecting to \(device.name)…")
            startConnectTimeout()
            return
        }
        
        vlog("connect(at:) → starting fresh connect to \(device.name)")
        pendingConnectDeviceName = device.name
        onStateChanged?("Connecting to \(device.name)…")
        polarManager.connect(to: device)
        startConnectTimeout()   // ⏱️ guard against silent failures
    }
    
    func disconnect() {
        vlog("disconnect()")
        polarManager.disconnect()
    }
    
    /// Optional button: manually trigger a firmware check/update.
    func checkAndUpdateFirmware(minBatteryPercent: UInt? = 30) {
        polarManager.checkAndUpdateFirmwareIfNeeded(autoUpdate: true, minBatteryPercent: minBatteryPercent, firmwareURL: nil)
    }
    
    /// Optional QA path: sideload a specific firmware package
    func sideLoadFirmware(from url: URL, minBatteryPercent: UInt? = 30) {
        polarManager.checkAndUpdateFirmwareIfNeeded(autoUpdate: true, minBatteryPercent: minBatteryPercent, firmwareURL: url)
    }
    
    // Convenience accessors for your table view if you want them
    var devicesCount: Int { discoveredDevices.count }
    func deviceDisplayName(at index: Int) -> String? {
        guard index >= 0, index < discoveredDevices.count else { return nil }
        let d = discoveredDevices[index]
        return "\(d.name) • \(d.id)"
    }
    
    // MARK: - Timeout guard
    private func startConnectTimeout() {
        connectTimeout?.invalidate()
        connectTimeout = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            guard let self, self.pendingConnectDeviceName != nil else { return }
            self.vlog("connect timeout fired")
            self.pendingConnectDeviceName = nil
            self.onStateChanged?("Select a device to connect")
            self.onConnectionFailed?("Couldn’t connect. Make sure the device isn’t already connected in another app and is nearby.")
            // If your PolarManager exposes a cancel API, call it here:
            self.polarManager.cancelPendingConnectIfPossible()
        }
    }
    
    private func clearConnectTimeout() {
        connectTimeout?.invalidate()
        connectTimeout = nil
    }
}
