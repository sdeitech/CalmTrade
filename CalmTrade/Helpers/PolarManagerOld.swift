////
////  PolarManager.swift
////  CalmTrade
////
////  Created by Anas Parekh on 04/09/25.
////
//
//import Foundation
//import PolarBleSdk
//import CoreBluetooth
//import RxSwift
//import UIKit   // for in-app alerts
//import os.log
//
//// MARK: - Firmware notifications
//extension Notification.Name {
//    /// Posted with userInfo["status"] as CheckFirmwareUpdateStatus
//    static let ctFwCheck    = Notification.Name("ct.fw.check")
//    /// Posted with userInfo["progress"] as FirmwareProgress or userInfo["error"] as Error
//    static let ctFwProgress = Notification.Name("ct.fw.progress")
//}
//
//// MARK: - Models
//
//struct ScannedPolarDevice: Hashable {
//    let polarInfo: PolarDeviceInfo
//    var id: String { polarInfo.deviceId }
//    var name: String {
//        polarInfo.name
//            .replacingOccurrences(of: polarInfo.deviceId, with: "")
//            .trimmingCharacters(in: .whitespacesAndNewlines)
//    }
//    func hash(into hasher: inout Hasher) { hasher.combine(id) }
//    static func == (lhs: ScannedPolarDevice, rhs: ScannedPolarDevice) -> Bool { lhs.id == rhs.id }
//}
//
//struct PolarDeviceSnapshot {
//    let id: String
//    let name: String
//    let firmware: String?
//    let batteryLevel: UInt?
//    let charging: Bool?
//    let timestamp: Date
//}
//
//// Neutral progress model for UI
//struct FirmwareProgress {
//    let stage: String            // e.g. "Downloading", "Transferring", "Installing", "Rebooting", "Completed", "Error"
//    let detail: String?          // e.g. "45% (450/1000 KB)" or step name
//    let fraction: Double?        // 0.0 ... 1.0
//}
//
//// MARK: - Manager
//
//final class PolarManager: NSObject,
//                          PolarBleApiObserver,
//                          PolarBleApiDeviceInfoObserver,
//                          PolarBleApiDeviceHrObserver,
//                          PolarBleApiDeviceFeaturesObserver {
//    
//    // Singleton
//    static let shared = PolarManager()
//    
//    // MARK: - Persist last device for auto-reconnect
//    private let defaults = UserDefaults.standard
//    private let lastDeviceIdKey   = "ct.polar.lastDeviceId"
//    private let lastDeviceNameKey = "ct.polar.lastDeviceName"
//    
//    private var reconnectRetryWork: DispatchWorkItem?
//    private var isAutoReconnectInFlight = false
//    
//    private var lastBatteryLevel: UInt?
//    private var lastFirmwareVersion: String?
//    private var lastChargingState: BleBasClient.ChargeState?
//    
//    // MARK: - Public callbacks (used by VMs/VCs)
//    var onDevicesUpdated: (([ScannedPolarDevice]) -> Void)?
//    var onDeviceDiscovered: ((ScannedPolarDevice) -> Void)?
//    
//    var onConnectionStateChanged: ((ConnectionState) -> Void)?   // legacy single
//    private var connectionObservers: [UUID: (ConnectionState) -> Void] = [:] // multicast
//    
//    // Firmware update callbacks (legacy)
//    var onFwCheck: ((CheckFirmwareUpdateStatus) -> Void)?
//    var onFwStatus: ((FirmwareUpdateStatus) -> Void)?
//    var onFwError: ((Error) -> Void)?
//    
//    // Live vitals (LiveDataRouter subscribes to these)
//    var onHeartRate: ((Double, Date) -> Void)?
//    var onRRIntervals: (([Int], Date) -> Void)?
//    
//    // Optional: offline sync callbacks (hook these to your repo)
//    var onH10ExerciseEntry: ((PolarExerciseEntry) -> Void)?
//    var onH10ExerciseData:  ((PolarExerciseData) -> Void)?
//    var on360OfflineEntry:  ((PolarOfflineRecordingEntry) -> Void)?
//    var on360OfflinePpg:    ((PolarPpgData, Date) -> Void)?
//    
//    // Device meta snapshots (battery/firmware)
//    var onSnapshot: ((PolarDeviceSnapshot) -> Void)?
//    var onBatteryUpdate: ((String, UInt, Bool?) -> Void)?
//    
//    // RHR_avg computation result (optional UI hook)
//    var onRHRComputed: ((Double, CTMetricSource, String) -> Void)?
//    
//    /// Fires when any 360 offline PPG chunk is ingested (sleep-time likely if timestamps are at night).
//    var onOfflinePpgIngested: (( Date, Int) -> Void)?
//    
//    private var pendingBgCompletion: (() -> Void)?
//    private var lastBgAt: Date?
//    
//    // MARK: - Public state
//    
//    
//    enum ConnectionState {
//        case disconnected
//        case connecting(ScannedPolarDevice)
//        case connected(ScannedPolarDevice)
//    }
//    
//    private(set) var discoveredDevices = Set<ScannedPolarDevice>()
//    private(set) var connectionState: ConnectionState = .disconnected {
//        didSet {
//            onConnectionStateChanged?(connectionState)                 // legacy single
//            for cb in connectionObservers.values { cb(connectionState) } // multicast
//        }
//    }
//    private(set) var connectedDevice: ScannedPolarDevice?
//    
//    public private(set) var connectingDevice: ScannedPolarDevice?
//    
//    // MARK: - FTU callbacks for your VMs/VCs
//    var onFirstTimeUseNeeded: ((ScannedPolarDevice) -> Void)?
//    var onFtuProgress: ((String) -> Void)?
//    var onFtuCompleted: (() -> Void)?
//    var onFtuError: ((Error) -> Void)?
//    
//    private var ftuEvalPendingDeviceId: String?
//    private var ftuEvalRetryCount = 0
//    private let ftuEvalRetryMax = 6
//    
//    private var currentIdentifier: String? {
//        connectedDevice?.id
//    }
//    
//    // MARK: - Private
//    
//    var api: PolarBleApi!
//    private var searchDisposable: Disposable?
//    private var fwDisposable: Disposable?
//    
//    // Streaming disposables
//    private var hrStreamDisposable: Disposable?
//    private var ppiStreamDisposable: Disposable?
//    private var ecgStreamDisposable: Disposable?
//    private var ppgStreamDisposable: Disposable?
//    
//    let disposeBag = DisposeBag()
//    
//    private var fwRetryCount = 0
//    private let fwMaxRetries = 3
//    
//    private var isHrReady = false
//    private var hrStartRetry = 0
//    
//    /// Lightweight central just to read BT state.
//    private let central = CBCentralManager(delegate: nil, queue: nil, options: [
//        CBCentralManagerOptionShowPowerAlertKey: false
//    ])
//    
//    /// Prevent alert spam.
//    private var isShowingBluetoothAlert = false
//    private var lastBluetoothAlertAt: Date?
//    
//    private var streamingFeatureArmedAt: Date?
//    private var isPpiStarting = false
//    private var ppiStartRetry = 0
//    private var ppiStartDesired = false   // set true when we intend to run PPI once ready
//    
//    private var offlineStartInFlight = Set<String>()
//    private var offlineActive        = Set<String>()
//    
//    private let firstUseKeyPrefix = "ct.polar.firstUse."
//    
//    // Auto offline sync toggle
//    var autoOfflineSyncOnConnect: Bool = true
//    
//    private let fwLog = OSLog(subsystem: "CalmTrade", category: "Firmware")
//    private var isFwUpdatingInternal = false
//    
//    // MARK: - Init
//    
//    private override init() {
//        super.init()
//        api = PolarBleApiDefaultImpl.polarImplementation(
//            DispatchQueue.main,
//            features: [
//                .feature_hr,
//                .feature_polar_online_streaming,
//                .feature_battery_info,
//                .feature_device_info,
//                .feature_polar_firmware_update,
//                .feature_polar_features_configuration_service,
//                .feature_polar_sdk_mode,
//                .feature_polar_device_time_setup,
//                .feature_polar_activity_data,
//                .feature_polar_offline_recording,       // enables 360/OH1/Verity offline
//                .feature_polar_h10_exercise_recording
//            ]
//        )
//        api.observer = self
//        api.deviceInfoObserver = self
//        api.deviceHrObserver = self // readiness/fallback
//        api.deviceFeaturesObserver = self
//    }
//    
//    // MARK: - Discovery
//    
//    func startDeviceSearch() {
//        // If BT is off, prompt immediately and bail early.
//        if central.state == .poweredOff {
//            presentBluetoothOffAlertIfNeeded()
//            stopDeviceSearch()
//            return
//        }
//        
//        stopDeviceSearch()
//        discoveredDevices.removeAll()
//        onDevicesUpdated?([])
//        
//        searchDisposable = api.searchForDevice()
//            .observe(on: MainScheduler.instance)
//            .subscribe(onNext: { [weak self] sdkDevice in
//                guard let self else { return }
//                let dev = ScannedPolarDevice(polarInfo: sdkDevice)
//                if !self.discoveredDevices.contains(dev) {
//                    self.discoveredDevices.insert(dev)
//                    self.onDeviceDiscovered?(dev)
//                    self.onDevicesUpdated?(Array(self.discoveredDevices).sorted { $0.name < $1.name })
//                }
//            }, onError: { [weak self] (error: Error) in
//                if let self, self.central.state == .poweredOff {
//                    self.presentBluetoothOffAlertIfNeeded()
//                }
//                print("PolarManager: Device search error: \(error)")
//            })
//    }
//    
//    func stopDeviceSearch() {
//        searchDisposable?.dispose()
//        searchDisposable = nil
//    }
//    
//    // MARK: - Connect / Disconnect
//    
//    func connect(to device: ScannedPolarDevice) {
//        if central.state == .poweredOff {
//            presentBluetoothOffAlertIfNeeded()
//            return
//        }
//        
//        // ✅ If already connected to this device, short-circuit to "connected"
//        if let current = connectedDevice, current.id == device.id {
//            connectionState = .connected(current)
//            broadcastSnapshotIfCurrent()
//            return
//        }
//        
//        // ✅ If already *connecting* to this device, don't start again
//        if let inFlight = connectingDevice, inFlight.id == device.id {
//            connectionState = .connecting(inFlight)
//            return
//        }
//        
//        // If connected to a different device, disconnect first then try again
//        if let current = connectedDevice, current.id != device.id {
//            do { try api.disconnectFromDevice(current.id) } catch { NSLog("disconnect error: \(error)") }
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
//                self?.connect(to: device)
//            }
//            return
//        }
//        
//        // If *connecting* to a different device, cancel and retry
//        if let inFlight = connectingDevice, inFlight.id != device.id {
//            _ = cancelPendingConnectIfPossible()
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
//                self?.connect(to: device)
//            }
//            return
//        }
//        
//        // Normal fresh connect path
//        stopDeviceSearch()
//        connectingDevice = device
//        connectionState = .connecting(device)
//        
//        do {
//            try api.connectToDevice(device.id)
//            waitForConnection(deviceId: device.id)
//        } catch {
//            if central.state == .poweredOff { presentBluetoothOffAlertIfNeeded() }
//            print("PolarManager: Failed to start connection to \(device.id). Error: \(error)")
//            connectingDevice = nil
//            connectionState = .disconnected
//        }
//    }
//    
//    func disconnect() {
//        guard let dev = connectedDevice else { return }
//        do {
//            try api.disconnectFromDevice(dev.id)
//        } catch {
//            print("PolarManager: Failed to disconnect from \(dev.id). Error: \(error)")
//        }
//    }
//    
//    /// Attempts to cancel an in-flight connection (also works as a "cancel connect" on many SDKs).
//    @discardableResult
//    func cancelPendingConnectIfPossible() -> Bool {
//        guard let dev = connectingDevice else { return false }
//        do {
//            try api.disconnectFromDevice(dev.id) // cancels pending connect if not yet connected
//            return true
//        } catch {
//            NSLog("cancelPendingConnectIfPossible error: \(error)")
//            return false
//        }
//    }
//    
//    private func waitForConnection(deviceId: String) {
//        api.waitForConnection(deviceId)
//            .observe(on: MainScheduler.instance)
//            .subscribe(onCompleted: { [weak self] in
//                guard let self else { return }
//                
//                if let dev = self.connectedDevice {
//                    self.startBestStreaming(for: dev)   // live path
//                    
//                    if self.autoOfflineSyncOnConnect {
//                        // one ordered, idempotent sequence for offline
//                        self.ensureOfflinePipeline(for: dev.id)
//                    }
//                }
//            }, onError: { err in
//                print("waitForConnection error:", err)
//            })
//            .disposed(by: disposeBag)
//    }
//    
//    // MARK: - Observers API
//    
//    @discardableResult
//    func addConnectionObserver(_ block: @escaping (ConnectionState) -> Void) -> UUID {
//        let id = UUID()
//        connectionObservers[id] = block
//        block(connectionState) // snapshot
//        return id
//    }
//    
//    func removeConnectionObserver(_ id: UUID) {
//        connectionObservers.removeValue(forKey: id)
//    }
//    
//    // MARK: - Firmware Update (existing API kept)
//    
//    func checkAndUpdateFirmwareIfNeeded(
//        autoUpdate: Bool = true,
//        minBatteryPercent: UInt? = nil,
//        firmwareURL: URL? = nil
//    ) {
//        guard case .connected(let dev) = connectionState else { return }
//        
//        // Skip unsupported: watches (e.g., Polar 360) not updatable via SDK
//        guard supportsSdkFirmwareUpdate(dev) else {
//            onFwCheck?(.checkFwUpdateFailed(details: "Not supported on this device"))
//            return
//        }
//        
//        if let min = minBatteryPercent, let lvl = lastBatteryLevel, lvl < min {
//            let msg = "Battery \(lvl)% below threshold \(min)% — skipping FWU check."
//            onFwCheck?(.checkFwUpdateFailed(details: msg))
//            return
//        }
//        
//        fwDisposable?.dispose()
//        fwDisposable = api.checkFirmwareUpdate(dev.id)
//            .observe(on: MainScheduler.instance)
//            .subscribe(onNext: { [weak self] status in
//                guard let self = self else { return }
//                self.onFwCheck?(status)
//                switch status {
//                case .checkFwUpdateAvailable:
//                    if autoUpdate { self.startFirmwareUpdate(identifier: dev.id, firmwareURL: firmwareURL) }
//                case .checkFwUpdateNotAvailable, .checkFwUpdateFailed:
//                    break
//                }
//            }, onError: { [weak self] err in
//                self?.onFwError?(err)
//            })
//    }
//    
//    func checkFirmwareUpdateNonForced(minBatteryPercent: UInt = 30) {
//        guard !isFwUpdatingInternal else {
//                os_log("[FW] checkFirmwareUpdateNonForced ignored: update in progress", log: fwLog, type: .info)
//                return
//            }
//        guard case .connected(let dev) = connectionState else {
//            onFwCheck?(.checkFwUpdateFailed(details: "No connected device"))
//            NotificationCenter.default.post(name: .ctFwCheck, object: nil,
//                                            userInfo: ["status": CheckFirmwareUpdateStatus.checkFwUpdateFailed(details: "No connected device")])
//            return
//        }
//        
//        guard supportsSdkFirmwareUpdate(dev) else {
//            let s: CheckFirmwareUpdateStatus = .checkFwUpdateFailed(details: "Not supported on this device")
//            onFwCheck?(s)
//            NotificationCenter.default.post(name: .ctFwCheck, object: nil, userInfo: ["status": s])
//            return
//        }
//        
//        if let lvl = lastBatteryLevel, lvl < minBatteryPercent {
//            let msg = "Battery \(lvl)% below threshold \(minBatteryPercent)% — skipping FWU check."
//            let s: CheckFirmwareUpdateStatus = .checkFwUpdateFailed(details: msg)
//            onFwCheck?(s)
//            NotificationCenter.default.post(name: .ctFwCheck, object: nil, userInfo: ["status": s])
//            return
//        }
//        
//        fwDisposable?.dispose()
//        fwDisposable = api.checkFirmwareUpdate(dev.id)
//            .observe(on: MainScheduler.instance)
//            .subscribe(onNext: { [weak self] status in
//                guard let self else { return }
//                self.onFwCheck?(status)
//                NotificationCenter.default.post(name: .ctFwCheck, object: nil, userInfo: ["status": status])
//            }, onError: { [weak self] err in
//                self?.onFwError?(err)
//                NotificationCenter.default.post(name: .ctFwCheck, object: nil, userInfo: [
//                    "status": CheckFirmwareUpdateStatus.checkFwUpdateFailed(details: err.localizedDescription)
//                ])
//            })
//    }
//    
//    func beginFirmwareUpdate() {
//        guard case .connected(let dev) = connectionState else {
//            NotificationCenter.default.post(name: .ctFwProgress, object: nil,
//                                            userInfo: ["progress": FirmwareProgress(stage: "Error", detail: "No connected device", fraction: nil)])
//            return
//        }
//        startFirmwareUpdate(identifier: dev.id, firmwareURL: nil)
//    }
//    
//    private func startFirmwareUpdate(identifier: String, firmwareURL: URL? = nil) {
//        let attemptId = UUID().uuidString.prefix(8) // short tag per attempt
//
//        os_log("[FW %@] ▶️ startFirmwareUpdate(id=%{public}@, url?=%{public}@)",
//               log: fwLog, type: .info, String(attemptId), identifier, firmwareURL?.absoluteString ?? "nil")
//
//        fwDisposable?.dispose()
//        os_log("[FW %@] disposed previous fwDisposable (if any)", log: fwLog, type: .debug, String(attemptId))
//
//        let src: Observable<FirmwareUpdateStatus> = (firmwareURL != nil)
//            ? api.updateFirmware(identifier, fromFirmwareURL: firmwareURL!)
//            : api.updateFirmware(identifier)
//
//        let stream = src
////            .timestamp()// add Rx timestamp
//            .materialize()             // see next/error/completed uniformly
//            .share(replay: 0)          // no cross-sub reuse
//
//        fwDisposable = stream
//            .do(onSubscribe: { [weak self] in
//                os_log("[FW %@] subscription started", log: self!.fwLog, type: .info, String(attemptId))
//                NotificationCenter.default.post(name: .ctFwProgress, object: nil,
//                    userInfo: ["progress": FirmwareProgress(stage: "Starting", detail: "Preparing update…", fraction: 0.0),
//                               "attemptId": String(attemptId)])
//                // self?.isFwUpdating = true // if you track it here
//            }, onDispose: {
//                os_log("[FW %@] subscription disposed", log: self.fwLog, type: .debug, String(attemptId))
//            })
//            .observe(on: MainScheduler.instance)
//            .subscribe(onNext: { [weak self] event in
//                guard let self else { return }
//                switch event {
//                case .next(let stamped):
//                    let status = stamped
//                    let p = self.normalize(status: status)
//                    os_log("[FW %@] onNext %@ → stage=%{public}@ detail=%{public}@ fraction=%{public}@",
//                           log: fwLog, type: .info, String(attemptId),
//                           String(describing: status),
//                           p.stage, p.detail ?? "nil",
//                           p.fraction != nil ? String(format: "%.3f", p.fraction!) : "nil")
//
//                    self.onFwStatus?(status)
//                    self.broadcastSnapshotIfCurrent()
//
//                    NotificationCenter.default.post(name: .ctFwProgress, object: nil,
//                        userInfo: ["progress": p, "attemptId": String(attemptId)])
//                    
//                    self.isFwUpdatingInternal = false
//
//                case .error(let err):
//                    os_log("[FW %@] ❌ error: %{public}@", log: fwLog, type: .error, String(attemptId), err.localizedDescription)
//                    self.onFwError?(err)
//                    NotificationCenter.default.post(name: .ctFwProgress, object: nil,
//                        userInfo: ["error": err, "attemptId": String(attemptId)])
//                    self.isFwUpdatingInternal = false                     // 👈 clear on error
//
//                case .completed:
//                    os_log("[FW %@] ✅ completed", log: fwLog, type: .info, String(attemptId))
//                    NotificationCenter.default.post(name: .ctFwProgress, object: nil,
//                        userInfo: ["progress": FirmwareProgress(stage: "Completed", detail: nil, fraction: 1.0),
//                                   "attemptId": String(attemptId)])
//                    self.isFwUpdatingInternal = false
//                }
//            })
//    }
//    
//    private func supportsSdkFirmwareUpdate(_ device: ScannedPolarDevice) -> Bool {
//        api.isFeatureReady(device.id, feature: .feature_polar_firmware_update)
//    }
//    
//    private func normalize(status: FirmwareUpdateStatus) -> FirmwareProgress {
//        switch status {
//        case .fetchingFwUpdatePackage(let d):
//            return .init(stage: "Fetching", detail: d, fraction: 0.10)
//        case .preparingDeviceForFwUpdate(let d):
//            return .init(stage: "Preparing device", detail: d, fraction: 0.45)
//        case .writingFwUpdatePackage(let d):
//            return .init(stage: "Writing", detail: d, fraction: 0.75)
//        case .finalizingFwUpdate(let d):
//            return .init(stage: "Finalizing", detail: d, fraction: 0.97)
//        case .fwUpdateCompletedSuccessfully(let d):
//            return .init(stage: "Completed", detail: d.isEmpty ? nil : d, fraction: 1.0)
//        case .fwUpdateNotAvailable(let d):
//            return .init(stage: "Not available", detail: d.isEmpty ? "Your device is up to date." : d, fraction: nil)
//        case .fwUpdateFailed(let d):
//            return .init(stage: "Error", detail: d.isEmpty ? "Unknown error" : d, fraction: nil)
//        }
//    }
//
//    private func percentFrom(details: String) -> Double? {
//        // 1) Explicit "NN%" pattern
//        if let m = details.range(of: #"(\d{1,3})\s*%"#, options: .regularExpression) {
//            let pctString = String(details[m]).replacingOccurrences(of: "%", with: "")
//            if let pct = Double(pctString), pct >= 0, pct <= 100 { return pct / 100.0 }
//        }
//        // 2) "x/y" bytes pattern
//        if let m = details.range(of: #"(\d+)\s*/\s*(\d+)"#, options: .regularExpression) {
//            let pair = String(details[m]).split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
//            if pair.count == 2, let x = Double(pair[0]), let y = Double(pair[1]), y > 0 { return min(1.0, x / y) }
//        }
//        // 3) "x of y" pattern
//        if let m = details.range(of: #"(\d+)\s+of\s+(\d+)"#, options: .regularExpression) {
//            let nums = String(details[m]).components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Double.init)
//            if nums.count >= 2, nums[1] > 0 { return min(1.0, nums[0] / nums[1]) }
//        }
//        return nil
//    }
//
//    /// Clamp and re-range a fraction inside [a, b], useful to visually spread stages on a single bar.
//    private func map(_ f: Double?, into minV: Double, _ maxV: Double) -> Double? {
//        guard let f else { return nil }
//        let clamped = max(0.0, min(1.0, f))
//        return minV + (maxV - minV) * clamped
//    }
//    
//    // MARK: - PolarBleApiObserver
//    
//    func deviceConnecting(_ info: PolarDeviceInfo) {
//        isAutoReconnectInFlight = false
//        let dev = ScannedPolarDevice(polarInfo: info)
//        connectingDevice = dev
//        connectionState = .connecting(dev)
//    }
//    
//    func deviceConnected(_ info: PolarDeviceInfo) {
//        let dev = ScannedPolarDevice(polarInfo: info)
//        connectedDevice = dev
//        connectingDevice = nil
//        connectionState = .connected(dev)
//        NSLog("[PM] deviceConnected id=\(dev.id) name=\(dev.name)")
//        
//        NSLog("[PM] deviceConnected → arming FTU")
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
//            self.probeFtuStatus(reason: "post-connect")
//        }
//        
//        let lowered = dev.name.lowercased()
//        DeviceManager.shared.currentSource = lowered.contains("h10") ? .polarH10 : .polar360
//        
//        // ✅ Ensure Polar 360/OH1/Verity offline PPG recording is active
//        if lowered.contains("360") || lowered.contains("verity") || lowered.contains("oh1") {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
//                self?.start360OfflinePpg(dev.id)
//            }
//        }
//        
//        //        if lowered.contains("360"), isFirstTimeUse(for: dev) {
//        //            DispatchQueue.main.async { [weak self] in self?.onFirstTimeUseNeeded?(dev) }
//        //        }
//        
//        defaults.set(dev.id,   forKey: lastDeviceIdKey)
//        defaults.set(dev.name, forKey: lastDeviceNameKey)
//        
//        // Kick readiness gate (will also trigger offline sync in waitForConnection)
//        waitForConnection(deviceId: dev.id)
//        
//        isHrReady = false
//        hrStartRetry = 0
//        
//        NSLog("[PM] connected; waiting for DIS callbacks (firmware/software revision)")
//        broadcastSnapshotIfCurrent()
//        
//        PolarDailySyncCoordinator.shared.startWhileConnected(deviceId: dev.id)
//    }
//    
//    // Some SDKs use a simpler signature: func deviceDisconnected(_ identifier: String) { ... }
//    func deviceDisconnected(_ identifier: PolarDeviceInfo, pairingError: Bool) {
//        isAutoReconnectInFlight = false
//        connectedDevice = nil
//        connectingDevice = nil
//        connectionState = .disconnected
//        DeviceManager.shared.currentSource = .appleHealthKit
//        stopAllStreaming()
//        PolarDailySyncCoordinator.shared.stop()
//        
//        // reset streaming guards
//        streamingFeatureArmedAt = nil
//        isPpiStarting = false
//        ppiStartRetry = 0
//        isHrReady = false
//        hrStartRetry = 0
//    }
//    
//    func blePowerOn() {
//        attemptAutoReconnectIfNeeded()
//    }
//    
//    func blePowerOff() {
//        reconnectRetryWork?.cancel()
//        reconnectRetryWork = nil
//        presentBluetoothOffAlertIfNeeded()
//    }
//    
//    private func armFtuEvaluation(for dev: ScannedPolarDevice) {
//        ftuEvalPendingDeviceId = dev.id
//        ftuEvalRetryCount = 0
//        // Try once now (in case the feature is already ready) and then with a few timed retries.
//        maybeEvaluateFTU(reason: "initial-after-connect")
//        scheduleFtuRetry()
//    }
//    
//    private func scheduleFtuRetry() {
//        guard let id = ftuEvalPendingDeviceId, ftuEvalRetryCount < ftuEvalRetryMax else { return }
//        let delay = 0.35 + Double(ftuEvalRetryCount) * 0.25
//        ftuEvalRetryCount += 1
//        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
//            guard let self = self, self.ftuEvalPendingDeviceId == id else { return }
//            self.maybeEvaluateFTU(reason: "retry-\(self.ftuEvalRetryCount)")
//            self.scheduleFtuRetry()
//        }
//    }
//    
//    private func probeFtuStatus(reason: String, attempt: Int = 0) {
//        guard case .connected(let dev) = connectionState else { return }
//        NSLog("[PM][FTU] probe(\(reason)) attempt=\(attempt+1)")
//        
//        Task {
//            do {
//                let done = try await api.isFtuDone(dev.id).value
//                NSLog("[PM][FTU] isFtuDone -> \(done)")
//                if !done { self.onFirstTimeUseNeeded?(dev) }
//            } catch let gatt as BleGattException {
//                // Happens right after connect while notifications aren’t enabled yet.
////                switch gatt {
////                case .notificationNotEnabled:
////                    if attempt < 6 {
////                        let delay = 0.40 + 0.20 * Double(attempt)
////                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
////                            self.probeFtuStatus(reason: "retry-\(attempt+1)", attempt: attempt + 1)
////                        }
////                        return
////                    }
////                default: break
////                }
//                NSLog("[PM][FTU] isFtuDone gatt error: \(gatt)")
//                // If we can’t confirm, be conservative and show FTU UI anyway.
//                self.onFirstTimeUseNeeded?(dev)
//            } catch {
//                NSLog("[PM][FTU] isFtuDone error: \(error)")
//                // Unknown error — still surface FTU so user can try.
//                self.onFirstTimeUseNeeded?(dev)
//            }
//        }
//    }
//    
//    private func maybeEvaluateFTU(reason: String) {
//        guard let dev = connectedDevice else { return }
//        let n = dev.name.lowercased()
//        let looksLikeWrist = n.contains("360") || n.contains("verity") || n.contains("oh1")
//        || n.contains("ignite") || n.contains("pacer") || n.contains("unite")
//        || n.contains("vantage") || n.contains("grit")
//        guard looksLikeWrist else { return }
//        
//        NSLog("[PM][FTU] maybeEvaluateFTU(\(reason)) – probing isFtuDone()")
//        Task {
//            do {
//                let done = try await api.isFtuDone(dev.id).value
//                NSLog("[PM][FTU] isFtuDone -> \(done)")
//                if !done { self.onFirstTimeUseNeeded?(dev) }
//            } catch {
//                // If the API isn’t supported on this model/firmware you’ll land here.
//                // Be conservative and show FTU anyway; your UI can still attempt doFirstTimeUse and handle error.
//                NSLog("[PM][FTU] isFtuDone error: \(error)")
//                self.onFirstTimeUseNeeded?(dev)
//            }
//        }
//    }
//    
//    /// Call after you transition to "connected"; decides whether to prompt FTU.
//    func evaluateFirstTimeUseIfNeeded(for dev: ScannedPolarDevice) {
//        Task {
//            guard let id = currentIdentifier else { return }
//            
//            // Gate on devices that actually support the config service
//            let cfgReady = api.isFeatureReady(id, feature: .feature_polar_features_configuration_service)
//            NSLog("[PM][FTU] feature CFG ready on %@: %@", id, cfgReady.description)
//            guard cfgReady else { return } // no FTU without this feature
//            
//            // Broaden heuristic: 360, Verity, OH1, Ignite, Pacer, Unite, Grit X, Vantage, etc.
//            let n = dev.name.lowercased()
//            let looksLikeWrist =
//            n.contains("360") || n.contains("verity") || n.contains("oh1") ||
//            n.contains("ignite") || n.contains("pacer") || n.contains("unite") ||
//            n.contains("vantage") || n.contains("grit")
//            NSLog("[PM][FTU] wrist-like=%@ for name='%@'", looksLikeWrist.description, dev.name)
//            guard looksLikeWrist else { return }
//            
//            do {
//                let done = try await api.isFtuDone(id).value
//                NSLog("[PM][FTU] isFtuDone(%@) -> %@", id, done.description)
//                if !done { self.onFirstTimeUseNeeded?(dev) }
//            } catch {
//                NSLog("[PM][FTU] isFtuDone error: %@", String(describing: error))
//                self.onFirstTimeUseNeeded?(dev) // be conservative
//            }
//        }
//    }
//    
//    /// Send FTU config → set local time → (optional) restart.
//    func performFirstTimeUse(config: PolarFirstTimeUseConfig, restartAfter: Bool = false) {
//        Task {
//            guard let id = currentIdentifier else { return }
//            await MainActor.run { self.onFtuProgress?("Sending setup…") }
//            _ = try await api.doFirstTimeUse(id, ftuConfig: config).value
//            await MainActor.run { self.onFtuProgress?("Syncing time…") }
//            _ = try await api.setLocalTime(id, time: Date(), zone: .current).value
//            if restartAfter {
//                await MainActor.run { self.onFtuProgress?("Restarting…") }
//                do { _ = try await api.doRestart(id, preservePairingInformation: true).value }
//                catch let gatt as BleGattException where gatt == .gattDisconnected { /* expected */ }
//            }
//            await MainActor.run { self.onFtuCompleted?() }
//        }
////        .result { error in
////            Task { @MainActor in self.onFtuError?(error) }
////        }
//    }
//    
//    // MARK: - PolarBleApiDeviceInfoObserver
//    
//    func disInformationReceived(_ identifier: String, uuid: CBUUID, value: String) {
//        // optional diagnostic
//    }
//    
//    func disInformationReceivedWithKeysAsStrings(_ identifier: String, key: String, value: String) {
//        let k = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
//        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
//        NSLog("[PM] DIS key='\(k)' value='\(v)' from \(identifier)")
//        
//        // Known DIS UUIDs:
//        // 2a24 = Model Number, 2a25 = Serial Number, 2a26 = Firmware Revision,
//        // 2a27 = Hardware Revision, 2a28 = Software Revision, 2a29 = Manufacturer
//        let isFirmwareishUuid = (k == "2a26") || (k == "2a28")
//        let isFirmwareishName = k.contains("firmware") || k.contains("software")
//        || k.contains("revision") || k.contains("version")
//        
//        if isFirmwareishUuid || isFirmwareishName {
//            lastFirmwareVersion = v
//            NSLog("[PM] captured firmware/software string='\(v)'")
//            broadcastSnapshotIfCurrent()
//            return
//        }
//    }
//    
//    func batteryLevelReceived(_ identifier: String, batteryLevel: UInt) {
//        lastBatteryLevel = batteryLevel
//        NSLog("[PM] battery level \(batteryLevel)% for \(identifier)")
//        onBatteryUpdate?(identifier, batteryLevel, nil)
//        broadcastSnapshotIfCurrent()
//    }
//    
//    func batteryChargingStatusReceived(_ identifier: String, chargingStatus: BleBasClient.ChargeState) {
//        lastChargingState = chargingStatus
//        NSLog("[PM] charging state \(chargingStatus) for \(identifier)")
//        onBatteryUpdate?(identifier, lastBatteryLevel ?? 0, chargingStatus == .charging)
//        broadcastSnapshotIfCurrent()
//    }
//    
//    // MARK: - PolarBleApiDeviceHrObserver
//    
//    func hrFeatureReady(_ identifier: String) {
//        guard let dev = connectedDevice, dev.id == identifier else { return }
//        isHrReady = true
//        hrStartRetry = 0
//        // Kick HR specifically; PPI is handled separately.
//        startHrStreamingIfPossible(for: dev)
//    }
//    
//    func hrValueReceived(_ identifier: String,
//                         data: (hr: UInt8, rrs: [Int], rrsMs: [Int],
//                                contact: Bool, contactSupported: Bool)) {
//        // Only skip when explicit HR streaming is already active.
//        if hrStreamDisposable != nil { return }
//        if data.contactSupported && !data.contact { return }
//        
//        let ts = Date()
//        onHeartRate?(Double(data.hr), ts)
//        
//        if !data.rrsMs.isEmpty {
//            onRRIntervals?(data.rrsMs.map { Int($0) }, ts)
//        } else if !data.rrs.isEmpty {
//            let rrMs = data.rrs.map { Int((Double($0) / 1024.0) * 1000.0) }
//            onRRIntervals?(rrMs, ts)
//        }
//    }
//    
//    // MARK: - Live streaming selector
//    
//    /// Chooses PPI on optical devices (e.g., Polar 360/Verity/OH1) and HR+RR on ECG straps (H9/H10),
//    /// based on actual capabilities reported by the device.
//    private func startBestStreaming(for device: ScannedPolarDevice) {
//        stopAllStreaming()
//        
//        // Always try HR (from HR characteristic only)
//        startHrStreamingIfPossible(for: device)
//        
//        let name = device.name.lowercased()
//        let isOptical = name.contains("360") || name.contains("verity") || name.contains("oh1")
//        
//        if isOptical {
//            // We want PPI, but only once the feature is ready
//            ppiStartDesired = true
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
//                self.maybeStartPpiWhenReady(for: device)
//            }
//            return
//        }
//        
//        // Straps: only run PPI if the device actually exposes it
//        api.getAvailableOnlineStreamDataTypes(device.id)
//            .observe(on: MainScheduler.instance)
//            .subscribe(onSuccess: { [weak self] types in
//                guard let self else { return }
//                if types.contains(.ppi) {
//                    self.ppiStartDesired = true
//                    self.maybeStartPpiWhenReady(for: device)
//                } else {
//                    self.ppiStartDesired = false
//                }
//            }, onFailure: { [weak self] _ in
//                self?.ppiStartDesired = false
//            })
//            .disposed(by: disposeBag)
//    }
//    
//    private func startHrStreamingIfPossible(for device: ScannedPolarDevice) {
//        let name = device.name.lowercased()
//        let isStrap = name.contains("h10") || name.contains("h9")
//        
//        if isStrap && !isHrReady {
//#if DEBUG
//            print("HR not ready yet; waiting for hrFeatureReady()")
//#endif
//            return
//        }
//        
//        if hrStreamDisposable != nil { return }
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
//            self?.startHrStreaming(for: device)
//        }
//    }
//    
//    // MARK: - HR streaming (H9/H10)
//    
//    private func startHrStreaming(for device: ScannedPolarDevice) {
//        stopHrStreaming()
//        
//        hrStreamDisposable = api.startHrStreaming(device.id)
//            .observe(on: MainScheduler.instance)
//            .subscribe(onNext: { [weak self] samples in
//                guard let self = self else { return }
//                let ts = Date()
//                
//                if let last = samples.last {
//                    self.onHeartRate?(Double(last.hr), ts)
//                }
//                
//                let allRRs = samples
//                    .filter { $0.rrAvailable && !$0.rrsMs.isEmpty }
//                    .flatMap { $0.rrsMs.map { Int($0) } }
//                if !allRRs.isEmpty {
//                    self.onRRIntervals?(allRRs, ts)
//                }
//                
//#if DEBUG
//                let rrsPerSample = samples.map { $0.rrsMs.count }
//                let totalRRs = rrsPerSample.reduce(0, +)
//                print("POLAR HR batch: samples=\(samples.count) hrs=[\(samples.map{$0.hr})] rrsMsPerSample=\(rrsPerSample) totalRRs=\(totalRRs)")
//#endif
//            }, onError: { [weak self] error in
//                guard let self = self else { return }
//                print("HR stream error: \(error)")
//                
//                let msg = String(describing: error).lowercased()
//                if msg.contains("notificationnotenabled") || msg.contains("notification not enabled") {
//                    if self.hrStartRetry < 2 {
//                        self.hrStartRetry += 1
//                        self.stopHrStreaming()
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
//                            if let dev = self.connectedDevice {
//                                self.startHrStreamingIfPossible(for: dev)
//                            }
//                        }
//                        return
//                    }
//                }
//                
//                self.stopHrStreaming()
//            })
//    }
//    
//    // MARK: - PPI streaming (Optical: 360/OH1/Verity) → RR-like ms
//    
//    private func startPpiStreaming(for device: ScannedPolarDevice, attempt: Int = 0) {
//        if isPpiStarting { return }
//        if ppiStreamDisposable != nil { return }
//        
//        isPpiStarting = true
//        ppiStartRetry = attempt
//        
//#if DEBUG
//        print("📡 startPpiStreaming attempt \(attempt + 1) on \(device.name)")
//#endif
//        
//        ppiStreamDisposable = api.startPpiStreaming(device.id)
//            .observe(on: MainScheduler.instance)
//            .subscribe(onNext: { [weak self] ppiData in
//                guard let self = self else { return }
//                self.isPpiStarting = false
//                let ts = Date()
//                
//#if DEBUG
//                print("📡 PPI subscribed on \(device.name)")
//#endif
//                
//                // Only RR-like intervals from PPI:
//                let rr = ppiData.samples.map { Int($0.ppInMs) }
//                if !rr.isEmpty { self.onRRIntervals?(rr, ts) }
//                
//#if DEBUG
//                print("PPI batch rrCount=\(rr.count) ts=\(ts)")
//#endif
//                
//                // ❌ DO NOT forward ppiData.samples.last?.hr as heart rate anymore.
//            }, onError: { [weak self] error in
//                guard let self = self else { return }
//                self.isPpiStarting = false
//                self.ppiStreamDisposable?.dispose()
//                self.ppiStreamDisposable = nil
//                
//                let msg = String(describing: error).lowercased()
//                
//                if (msg.contains("notificationnotenabled") || msg.contains("notification not enabled")),
//                   self.ppiStartRetry < 3 {
//                    let delay = 0.6 + 0.2 * Double(self.ppiStartRetry)
//                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
//                        self.startPpiStreaming(for: device, attempt: self.ppiStartRetry + 1)
//                    }
//                    return
//                }
//                
//                if msg.contains("already in state") && self.ppiStartRetry < 1 {
//                    self.stopAllStreaming()
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                        self.startPpiStreaming(for: device, attempt: self.ppiStartRetry + 1)
//                    }
//                    return
//                }
//                
//                print("❌ PPI stream error (giving up): \(error)")
//            })
//    }
//    
//    private func maybeStartPpiWhenReady(for device: ScannedPolarDevice, retry: Int = 0) {
//        guard ppiStartDesired else { return }
//        // already running or starting
//        if ppiStreamDisposable != nil || isPpiStarting { return }
//        
//        // Feature must be ready or PPI will silently fail
//        let ready = api.isFeatureReady(device.id, feature: .feature_polar_online_streaming)
//        if !ready {
//            if retry < 5 {
//                let delay = 0.35 + 0.15 * Double(retry)
//                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
//                    self.maybeStartPpiWhenReady(for: device, retry: retry + 1)
//                }
//            } else {
//#if DEBUG
//                print("PPI not ready after retries; giving up for now")
//#endif
//            }
//            return
//        }
//        
//        // If you want to be extra strict on straps, check types contain .ppi here.
//        startPpiStreaming(for: device)
//    }
//    
//    // MARK: - Optional: ECG & live PPG starters (if you need them externally)
//    
//    func startEcgStreaming(_ deviceId: String,
//                           onData: @escaping (PolarEcgData) -> Void) {
//        ecgStreamDisposable?.dispose()
//        api.requestStreamSettings(deviceId, feature: .ecg)
//            .asObservable() // Single -> Observable
//            .flatMap { [unowned self] settings -> Observable<PolarEcgData> in
//                self.api.startEcgStreaming(deviceId, settings: settings)
//            }
//            .observe(on: MainScheduler.instance)
//            .subscribe(onNext: { onData($0) },
//                       onError: { print("ECG error:", $0) })
//            .disposed(by: disposeBag)
//    }
//    
//    func startLivePpgStreaming(_ deviceId: String,
//                               onData: @escaping (PolarPpgData) -> Void) {
//        ppgStreamDisposable?.dispose()
//        api.requestStreamSettings(deviceId, feature: .ppg)
//            .asObservable() // Single -> Observable
//            .flatMap { [unowned self] settings -> Observable<PolarPpgData> in
//                self.api.startPpgStreaming(deviceId, settings: settings)
//            }
//            .observe(on: MainScheduler.instance)
//            .subscribe(onNext: { onData($0) },
//                       onError: { print("PPG error:", $0) })
//            .disposed(by: disposeBag)
//    }
//    
//    // MARK: - Stop streaming
//    
//    private func stopAllStreaming() {
//        hrStreamDisposable?.dispose();  hrStreamDisposable  = nil
//        ppiStreamDisposable?.dispose(); ppiStreamDisposable = nil
//        ecgStreamDisposable?.dispose(); ecgStreamDisposable = nil
//        ppgStreamDisposable?.dispose(); ppgStreamDisposable = nil
//        // 🔧 ensure we don't get stuck in "starting..." after a stop
//        isPpiStarting = false
//    }
//    
//    private func stopHrStreaming() {
//        hrStreamDisposable?.dispose()
//        hrStreamDisposable = nil
//    }
//    
//    // MARK: - Auto Reconnect
//    
//    private var lastRememberedDevice: (id: String, name: String)? {
//        guard let id = defaults.string(forKey: lastDeviceIdKey),
//              let name = defaults.string(forKey: lastDeviceNameKey),
//              !id.isEmpty, !name.isEmpty else { return nil }
//        return (id, name)
//    }
//    
//    private func attemptAutoReconnectIfNeeded() {
//        switch connectionState {
//        case .connected, .connecting:
//            return
//        case .disconnected:
//            break
//        }
//        
//        guard let remembered = lastRememberedDevice else { return }
//        guard !isAutoReconnectInFlight else { return }
//        
//        isAutoReconnectInFlight = true
//        reconnectRetryWork?.cancel()
//        reconnectRetryWork = nil
//        
//        do {
//            try api.connectToDevice(remembered.id)
//            waitForConnection(deviceId: remembered.id)
//        } catch {
//            scheduleReconnectRetry(seconds: 5)
//            isAutoReconnectInFlight = false
//        }
//    }
//    
//    private func scheduleReconnectRetry(seconds: TimeInterval) {
//        reconnectRetryWork?.cancel()
//        let work = DispatchWorkItem { [weak self] in
//            self?.isAutoReconnectInFlight = false
//            self?.attemptAutoReconnectIfNeeded()
//        }
//        reconnectRetryWork = work
//        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
//    }
//    
//    /// Call once at app launch.
//    func enableAutoReconnectOnLaunch() {
//        attemptAutoReconnectIfNeeded()
//    }
//    
//    /// Call when app returns to foreground to catch missed attempts.
//    func resumeAutoReconnectOnForeground() {
//        attemptAutoReconnectIfNeeded()
//    }
//    
//    // MARK: - Snapshot refresh
//    
//    public func refreshSnapshot() {
//        broadcastSnapshotIfCurrent()
//    }
//    
//    // MARK: - PolarBleApiDeviceFeaturesObserver
//    
//    func bleSdkFeatureReady(_ identifier: String, feature: PolarBleSdkFeature) {
//        guard identifier == connectedDevice?.id else { return }
//        
//        switch feature {
//        case .feature_polar_online_streaming:
//            let now = Date()
//            if let last = streamingFeatureArmedAt, now.timeIntervalSince(last) < 1.0 { return }
//            streamingFeatureArmedAt = now
//            
//            guard let dev = connectedDevice else { return }
//            // Resume HR if applicable
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
//                self.startHrStreamingIfPossible(for: dev)
//            }
//            
//            // Only *request* PPI here; the helper will verify readiness and start once stable
//            let name = dev.name.lowercased()
//            let isOptical = name.contains("360") || name.contains("verity") || name.contains("oh1")
//            if isOptical || self.ppiStartDesired {
//                self.ppiStartDesired = true
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
//                    self.maybeStartPpiWhenReady(for: dev)
//                }
//            }
//            
//        case .feature_polar_offline_recording:
//            // Don’t call start/list directly; just ensure the ordered pipeline runs
//            ensureOfflinePipeline(for: identifier)
//            
//        case .feature_polar_features_configuration_service:
//            NSLog("[PM][FTU] CFG feature became ready; evaluating FTU now")
//            maybeEvaluateFTU(reason: "feature-ready-callback")
//            
//        case .feature_polar_activity_data:
//                NSLog("[PM][ACT] Activity feature ready — starting minute poller")
//                PolarDailySyncCoordinator.shared.startWhileConnected(deviceId: identifier)
//            
//        default:
//            break
//        }
//        
//        if feature == .feature_polar_online_streaming ||
//            feature == .feature_device_info ||
//            feature == .feature_polar_features_configuration_service {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//                self.probeFtuStatus(reason: "feature-ready:\(feature)")
//            }
//        }
//    }
//    
//    // MARK: - 360 Sleep → RHR_avg ingest
//    
//    func submitPolar360SleepPacket(_ packet: P360SleepPacket) {
//        finalizeNightlyRHR(packet: packet)
//    }
//    
//    // MARK: - Offline (H10 exercise recorder)
//    
//    func h10StartRecording(_ deviceId: String, exerciseId: String = UUID().uuidString) {
//        api.startRecording(deviceId, exerciseId: exerciseId, interval: .interval_1s, sampleType: .rr)
//            .subscribe(onCompleted: { print("H10 recording started") },
//                       onError: { print("H10 startRecording error:", $0) })
//            .disposed(by: disposeBag)
//    }
//    
//    func h10StopRecording(_ deviceId: String) {
//        api.stopRecording(deviceId)
//            .subscribe(onCompleted: { print("H10 recording stopped") },
//                       onError: { print("H10 stopRecording error:", $0) })
//            .disposed(by: disposeBag)
//    }
//    
//    func h10ListAndFetchExercises(_ deviceId: String) {
//        api.fetchStoredExerciseList(deviceId)
//            .observe(on: MainScheduler.instance)
//            .do(onNext: { [weak self] entry in
//                self?.onH10ExerciseEntry?(entry)
//            })
//            .flatMap { [unowned self] entry in
//                self.api.fetchExercise(deviceId, entry: entry).asObservable()
//            }
//            .subscribe(onNext: { [weak self] ex in
//                self?.onH10ExerciseData?(ex)
//            }, onError: { print("H10 fetch exercise error:", $0) })
//            .disposed(by: disposeBag)
//    }
//    
//    // MARK: - Offline (360/OH1/Verity PPG)
//    
//    func start360OfflinePpg(_ deviceId: String, attempt: Int = 0, completion: ((Bool) -> Void)? = nil) {
//        // Don’t spam starts if we already know it’s running
//        if offlineActive.contains(deviceId) {
//            completion?(true)
//            return
//        }
//        
//        api.requestOfflineRecordingSettings(deviceId, feature: .ppg)
//            .flatMapCompletable { [unowned self] settings in
//                NSLog("[PM] starting offline PPG with settings: \(settings)")
//                return self.api.startOfflineRecording(deviceId, feature: .ppg, settings: settings, secret: nil)
//            }
//            .subscribe(onCompleted: { [weak self] in
//                NSLog("[PM] 360 offline PPG started ✅")
//                self?.offlineActive.insert(deviceId)
//                completion?(true)
//            }, onError: { [weak self] err in
//                let msg = String(describing: err).lowercased()
//                
//                // Treat "Already in state" as success
//                if msg.contains("already in state") {
//                    NSLog("[PM] offline PPG already running — treating as started")
//                    self?.offlineActive.insert(deviceId)
//                    completion?(true)
//                    return
//                }
//                
//                // Early CCCD race → backoff and retry a few times
//                if msg.contains("notificationnotenabled") && attempt < 3 {
//                    let delay = 0.6 + 0.2 * Double(attempt)
//                    NSLog("[PM] startOfflineRecording notificationNotEnabled; retry in \(delay)s")
//                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
//                        self?.start360OfflinePpg(deviceId, attempt: attempt + 1, completion: completion)
//                    }
//                    return
//                }
//                
//                print("[PM] 360 start offline PPG error:", err)
//                completion?(false)
//            })
//            .disposed(by: disposeBag)
//    }
//    
//    // Helper: robust PPG sample counter across SDK variants
//    private func _ppgSampleCount(_ ppg: PolarPpgData) -> Int {
//        // Most recent SDKs: samples are tuples (timeStamp: UInt64, channelSamples: [Int32])
//        if let tuples = ppg.samples as? [(timeStamp: UInt64, channelSamples: [Int32])] {
//            return tuples.reduce(0) { $0 + $1.channelSamples.count }
//        }
//        // Fallback via reflection for older shapes
//        var total = 0
//        for s in ppg.samples {
//            let m = Mirror(reflecting: s)
//            if let ch = m.children.first(where: { $0.label == "channels" })?.value as? [[Int32]] {
//                total += ch.reduce(0) { $0 + $1.count }
//                continue
//            }
//            if let ch1 = m.children.first(where: { $0.label == "channelSamples" })?.value as? [Int32] {
//                total += ch1.count
//                continue
//            }
//        }
//        return total
//    }
//    
//    // ✅ 360 offline download: Observable (entries) → flatMap Single(record).asObservable() → onNext
//    func listAndDownload360Offline(_ deviceId: String, attempt: Int = 0) {
//        NSLog("[PM] listAndDownload360Offline begin (attempt \(attempt + 1)) for \(deviceId)")
//        api.listOfflineRecordings(deviceId)
//            .observe(on: MainScheduler.instance)
//            .do(onNext: { [weak self] entry in
//                guard let self else { return }
//                self.on360OfflineEntry?(entry)
//                NSLog("[PM] offline entry found: type=\(entry.type) size=\(entry.size) date=\(entry.date) path=\(entry.path)")
//            })
//            .flatMap { [unowned self] entry in
//                self.api.getOfflineRecord(deviceId, entry: entry, secret: nil)
//                    .map { (entry, $0) }
//                    .asObservable()
//            }
//            .subscribe(onNext: { [weak self] (entry, record) in
//                guard let self else { return }
//                switch record {
//                case .ppgOfflineRecordingData(let ppg, let startTime, let setting):
//                    // Extract authoritative sample-rate & channels from PolarSensorSetting
//                    let sr = PolarManager.extractSampleRateHz(from: setting) ?? 22
//                    let ch = PolarManager.extractChannels(from: setting) ?? 2
//                    
//                    let sampleCount = ppg.samples.reduce(0) { $0 + $1.channelSamples.count }
//                    NSLog("[PM] PPG offline downloaded: start=%@ setting=%@ sampleCount=%d",
//                          startTime as NSDate, String(describing: setting), sampleCount)
//                    
//                    // Persist raw and a tiny meta row for sleep estimator
//                    _ = OfflinePPGIngestor.shared.ingest(deviceId: deviceId,
//                                                         start: startTime,
//                                                         ppg: ppg,
//                                                         sampleRateHz: sr,
//                                                         channelsOverride: ch)
//                    
//                    onOfflinePpgIngested?(startTime, sampleCount)
//                    on360OfflinePpg?(ppg, startTime)
//                    
//                    // Clear entry so the device disk doesn’t fill up
//                    clearOfflineRecord(deviceId: deviceId, entry: entry)
//                    
//                default:
//                    NSLog("[PM] offline record of non-PPG type: \(record)")
//                }
//            }, onError: { [weak self] err in
//                guard let self = self else { return }
//                let msg = String(describing: err).lowercased()
//                
//                if msg.contains("notificationnotenabled") && attempt < 3 {
//                    let delay = 0.6 + 0.2 * Double(attempt)
//                    NSLog("[PM] listOfflineRecordings notificationNotEnabled; retry in \(delay)s")
//                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
//                        self.listAndDownload360Offline(deviceId, attempt: attempt + 1)
//                    }
//                    return
//                }
//                
//                // If CCCDs weren’t ready yet, try once after we ensure start path
//                if attempt == 0 {
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                        self.ensureOfflinePipeline(for: deviceId)
//                    }
//                }
//                
//                print("[PM] getOfflineRecord/listOfflineRecordings error:", err)
//            })
//            .disposed(by: disposeBag)
//    }
//    
//    private func kickOfflineSyncIfSupported(_ device: ScannedPolarDevice) {
//        let name = device.name.lowercased()
//        if name.contains("h10") {
//            h10ListAndFetchExercises(device.id)
//        } else if name.contains("360") || name.contains("verity") || name.contains("oh1") {
//            // Pull buffered SDK offline data (PPG today; extend for others when needed)
//            listAndDownload360Offline(device.id)
//        }
//    }
//}
//
//// MARK: - Bluetooth alert presentation
//
//private extension PolarManager {
//    
//    func presentBluetoothOffAlertIfNeeded() {
//        let now = Date()
//        if let last = lastBluetoothAlertAt, now.timeIntervalSince(last) < 5 { return }
//        guard !isShowingBluetoothAlert else { return }
//        lastBluetoothAlertAt = now
//        isShowingBluetoothAlert = true
//        
//        DispatchQueue.main.async {
//            let alert = UIAlertController(
//                title: "Turn On Bluetooth",
//                message: "Bluetooth is turned off. Enable it to find and connect to nearby Polar devices.",
//                preferredStyle: .alert
//            )
//            alert.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { [weak self] _ in
//                self?.isShowingBluetoothAlert = false
//                if let url = URL(string: UIApplication.openSettingsURLString) {
//                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
//                }
//            }))
//            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] _ in
//                self?.isShowingBluetoothAlert = false
//            }))
//            
//            if let top = UIApplication.topViewController() {
//                top.present(alert, animated: true, completion: nil)
//            } else {
//                self.isShowingBluetoothAlert = false
//            }
//        }
//    }
//}
//
//// MARK: - UIApplication helpers
//
//private extension UIApplication {
//    static func keyWindow() -> UIWindow? {
//        UIApplication.shared.connectedScenes
//            .compactMap { $0 as? UIWindowScene }
//            .flatMap { $0.windows }
//            .first { $0.isKeyWindow }
//    }
//}
//
//extension PolarManager {
//    
//    func isFirstTimeUse(for device: ScannedPolarDevice) -> Bool {
//        let key = firstUseKeyPrefix + device.id
//        return !defaults.bool(forKey: key)
//    }
//    
//    func markFirstTimeUseCompleted(for device: ScannedPolarDevice) {
//        let key = firstUseKeyPrefix + device.id
//        defaults.set(true, forKey: key)
//    }
//}
//
//// MARK: - RHR_avg computer (per spec) + persistence
//
//private extension PolarManager {
//    
//    struct _Window { let start: Date; let end: Date; let mean: Double; let q: String }
//    
//    func finalizeNightlyRHR(packet: P360SleepPacket) {
//        // 1) HealthKit RHR if present and <36h old
//        let repo = CTMetricsRepository.shared
//        let hkLatest = repo.latestValue(kind: .restingHeartRate, source: .appleHealth)
//        let hkAgeHours: Double? = hkLatest.map { Date().timeIntervalSince($0.date) / 3600.0 }
//        
//        if let hk = hkLatest, let age = hkAgeHours, age < 36 {
//            repo.upsert(kind: .restingHeartRate, value: hk.value, unit: "bpm", source: .appleHealth, date: hk.date)
//            LatestBiometricsCache.shared.update(from: CalmScoreBiometricInputs(
//                heartRate: nil, hrvInRmssd: nil, hrvInSdnn: nil, restingHeartRate: hk.value, sleepDurationInHours: nil
//            ))
//            onRHRComputed?(hk.value, .appleHealth, "good")
//            NotificationCenter.default.post(name: .ctMetricUpdated, object: nil, userInfo: ["kind": "restingHeartRate", "date": hk.date])
//            return
//        }
//        
//        // 2) Derive from Polar 360 last-night sleep
//        guard let derived = computeRHRFromPolar360(packet) else {
//            onRHRComputed?(Double.nan, .appleHealth, "unknown")
//            return
//        }
//        
//        var rhr = derived.value
//        // EWMA smoothing
//        let prev = repo.latestValue(kind: .restingHeartRate)?.value
//        if let prev { rhr = 0.7 * rhr + 0.3 * prev }
//        
//        // Disagreement guard vs HK if HK exists at all
//        if let hk = hkLatest {
//            let delta = abs(hk.value - rhr)
//            let preferHK = (delta > 8.0) && (derived.quality != "good")
//            if preferHK {
//                repo.upsert(kind: .restingHeartRate, value: hk.value, unit: "bpm", source: .appleHealth, date: hk.date)
//                LatestBiometricsCache.shared.update(from: CalmScoreBiometricInputs(
//                    heartRate: nil, hrvInRmssd: nil, hrvInSdnn: nil, restingHeartRate: hk.value, sleepDurationInHours: nil
//                ))
//                onRHRComputed?(hk.value, .appleHealth, "good")
//                NotificationCenter.default.post(name: .ctMetricUpdated, object: nil, userInfo: ["kind": "restingHeartRate", "date": hk.date])
//                return
//            }
//        }
//        
//        // Persist Polar 360 result
//        repo.upsert(kind: .restingHeartRate, value: rhr, unit: "bpm", source: .polar360, date: packet.sleepEnd)
//        LatestBiometricsCache.shared.update(from: CalmScoreBiometricInputs(
//            heartRate: nil, hrvInRmssd: nil, hrvInSdnn: nil, restingHeartRate: rhr, sleepDurationInHours: nil
//        ))
//        onRHRComputed?(rhr, .polar360, derived.quality)
//        NotificationCenter.default.post(name: .ctMetricUpdated, object: nil, userInfo: ["kind": "restingHeartRate", "date": packet.sleepEnd])
//    }
//    
//    func computeRHRFromPolar360(_ p: P360SleepPacket) -> (value: Double, quality: String)? {
//        // 1) Restful segments → prefer NREM (Light+Deep); else stillness
//        let nrem = p.stages
//            .filter { $0.stage == .light || $0.stage == .deep }
//            .map { ($0.start, $0.end) }
//        
//        let restful: [(Date, Date)]
//        if !nrem.isEmpty { restful = nrem }
//        else { restful = p.motions.filter { $0.still }.map { ($0.start, $0.end) } }
//        
//        guard !restful.isEmpty else { return nil }
//        
//        let hr = p.hrSeries.sorted { $0.ts < $1.ts }
//        
//        // 2) 5-minute rolling mean, 1-minute step, window quality filter (drop "poor")
//        var windows: [_Window] = []
//        for (rStart, rEnd) in restful {
//            var cursor = alignDown(rStart, stepSec: 60)
//            while cursor.addingTimeInterval(300) <= rEnd {
//                let wStart = cursor
//                let wEnd   = cursor.addingTimeInterval(300)
//                let samples = hr.filter { $0.ts >= wStart && $0.ts < wEnd }
//                if samples.count >= 30 {
//                    let mean = samples.reduce(0.0) { $0 + $1.bpm } / Double(samples.count)
//                    let q = mapQuality(p.ppgQuality(wStart, wEnd))
//                    if q != "poor" { windows.append(.init(start: wStart, end: wEnd, mean: mean, q: q)) }
//                }
//                cursor = cursor.addingTimeInterval(60)
//            }
//        }
//        guard !windows.isEmpty else { return nil }
//        
//        // 3) Trim to 10th–90th percentile of window means
//        let means = windows.map { $0.mean }.sorted()
//        let lo = percentile(means, 0.10), hi = percentile(means, 0.90)
//        let trimmed = windows.filter { $0.mean >= lo && $0.mean <= hi }
//        guard !trimmed.isEmpty else { return nil }
//        
//        // 4) Lowest 30 consecutive minutes (6 windows @ 1 min step)
//        var best: (value: Double, quality: String)?
//        if trimmed.count >= 6 {
//            for i in 0...(trimmed.count - 6) {
//                let slice = Array(trimmed[i..<i+6])
//                let consec = zip(slice, slice.dropFirst()).allSatisfy { $0.end == $1.start }
//                if !consec { continue }
//                let m = slice.map(\.mean).reduce(0, +) / 6.0
//                let q = dominantQuality(slice.map(\.q))
//                if best == nil || m < best!.value { best = (m, q) }
//            }
//        }
//        return best
//    }
//    
//    // MARK: - Small helpers
//    
//    func alignDown(_ t: Date, stepSec: TimeInterval) -> Date {
//        let x = floor(t.timeIntervalSince1970 / stepSec) * stepSec
//        return Date(timeIntervalSince1970: x)
//    }
//    
//    func percentile(_ xs: [Double], _ p: Double) -> Double {
//        guard !xs.isEmpty else { return .nan }
//        let pos = Double(xs.count - 1) * p
//        let lo = Int(floor(pos)), hi = Int(ceil(pos))
//        if lo == hi { return xs[lo] }
//        let w = pos - Double(lo)
//        return xs[lo] * (1 - w) + xs[hi] * w
//    }
//    
//    func mapQuality(_ q: P360SleepPacket.Quality) -> String {
//        switch q { case .good: return "good"; case .fair: return "fair"; case .poor: return "poor" }
//    }
//    
//    func dominantQuality(_ qs: [String]) -> String {
//        return qs.contains("fair") ? "fair" : "good"
//    }
//}
//
//// MARK: - Polar 360 Sleep → Staged episode (HK-like)
//
//extension PolarManager {
//    
//    /// Call right after your 360 sleep sync completes (same place you call submitPolar360SleepPacket).
//    func submitPolar360SleepStages(from packet: P360SleepPacket) {
//        let epi = buildSleepEpisode(from: packet)
//        CTMetricsRepository.shared.upsertSleepEpisode(epi)
//        
//        if let preferred = CTMetricsRepository.shared.preferredSleepEpisode(on: packet.sleepEnd) {
//            let hours = preferred.totalSeconds / 3600.0
//            LatestBiometricsCache.shared.update(from:
//                                                    CalmScoreBiometricInputs(heartRate: nil,
//                                                                             hrvInRmssd: nil,
//                                                                             hrvInSdnn: nil,
//                                                                             restingHeartRate: nil,
//                                                                             sleepDurationInHours: hours)
//            )
//        }
//        
//        NotificationCenter.default.post(name: .ctSleepUpdated, object: nil, userInfo: ["source": CTMetricSource.polar360])
//    }
//    
//    private func buildSleepEpisode(from p: P360SleepPacket) -> CTSleepEpisode {
//        let rawSegs: [CTSleepSegment] = p.stages.map { s in
//            CTSleepSegment(start: s.start,
//                           end: s.end,
//                           stage: mapStage(s.stage),
//                           quality: nil)
//        }
//        
//        let merged = mergeAdjacent(segments: sanitize(rawSegs))
//        let qualed = merged.map { seg -> CTSleepSegment in
//            let q = windowedQuality(of: seg, ppg: p.ppgQuality)
//            return CTSleepSegment(start: seg.start, end: seg.end, stage: seg.stage, quality: q)
//        }
//        
//        let nightQ = nightQuality(qualed.map { $0.quality ?? "fair" })
//        return CTSleepEpisode(date: p.sleepEnd, source: .polar360, segments: qualed, qualityFlag: nightQ)
//    }
//    
//    private func mapStage(_ st: P360SleepPacket.Stage) -> CTSleepStage {
//        switch st {
//        case .awake: return .awake
//        case .rem:   return .rem
//        case .light: return .light
//        case .deep:  return .deep
//        case .unknown: return .light
//        }
//    }
//    
//    private func sanitize(_ segs: [CTSleepSegment]) -> [CTSleepSegment] {
//        let sorted = segs.sorted { $0.start < $1.start }
//        var out: [CTSleepSegment] = []
//        for s in sorted {
//            guard s.end > s.start else { continue }
//            if let last = out.last, s.start < last.end {
//                let clamped = CTSleepSegment(start: last.end, end: max(s.end, last.end), stage: s.stage, quality: s.quality)
//                if clamped.end > clamped.start { out.append(clamped) }
//            } else {
//                out.append(s)
//            }
//        }
//        return out
//    }
//    
//    private func mergeAdjacent(segments: [CTSleepSegment]) -> [CTSleepSegment] {
//        guard !segments.isEmpty else { return [] }
//        var out: [CTSleepSegment] = [segments[0]]
//        for s in segments.dropFirst() {
//            if var last = out.last, last.stage == s.stage, last.end == s.start {
//                out.removeLast()
//                last = CTSleepSegment(start: last.start, end: s.end, stage: last.stage, quality: nil)
//                out.append(last)
//            } else {
//                out.append(s)
//            }
//        }
//        return out
//    }
//    
//    private func windowedQuality(of seg: CTSleepSegment,
//                                 ppg: (Date, Date) -> P360SleepPacket.Quality) -> String {
//        let step: TimeInterval = 5 * 60
//        var goods = 0, fairs = 0, poors = 0
//        var cursor = seg.start
//        while cursor < seg.end {
//            let end = min(seg.end, cursor.addingTimeInterval(step))
//            switch ppg(cursor, end) {
//            case .good: goods += 1
//            case .fair: fairs += 1
//            case .poor: poors += 1
//            }
//            cursor = end
//        }
//        if goods == 0, fairs == 0, poors == 0 { return "fair" }
//        if goods >= fairs && goods >= poors { return "good" }
//        if fairs >= goods && fairs >= poors { return "fair" }
//        return "poor"
//    }
//    
//    private func nightQuality(_ qs: [String]) -> String {
//        guard !qs.isEmpty else { return "fair" }
//        let n = Double(qs.count)
//        let poor = Double(qs.filter { $0 == "poor" }.count) / n
//        let fair = Double(qs.filter { $0 == "fair" }.count) / n
//        if poor > 0.20 { return "poor" }
//        if fair > 0.20 { return "fair" }
//        return "good"
//    }
//}
//
//// Add this helper inside PolarManager (private extension is fine)
//private extension PolarManager {
//    func broadcastSnapshotIfCurrent() {
//        guard case .connected(let dev) = connectionState else {
//            NSLog("[PM] broadcastSnapshotIfCurrent skipped (not connected)")
//            return
//        }
//        let snap = PolarDeviceSnapshot(id: dev.id,
//                                       name: dev.name,
//                                       firmware: lastFirmwareVersion,
//                                       batteryLevel: lastBatteryLevel,
//                                       charging: (lastChargingState == .charging),
//                                       timestamp: Date())
//        NSLog("[PM] broadcasting snapshot id=\(snap.id) name=\(snap.name) fw=\(snap.firmware ?? "nil") batt=\(snap.batteryLevel?.description ?? "nil") charging=\(String(describing: snap.charging))")
//        onSnapshot?(snap)
//        NotificationCenter.default.post(name: .ctDeviceSnapshotDidChange, object: nil, userInfo: [
//            "id": snap.id,
//            "name": snap.name,
//            "firmware": snap.firmware as Any,
//            "battery": snap.batteryLevel as Any,
//            "charging": snap.charging as Any,
//            "timestamp": snap.timestamp
//        ])
//    }
//}
//
//private extension PolarManager {
//    private static let diskPressureThreshold: Double = 0.80
//    private var diskCheckKey: String { "ct.polar.diskcheck.last" }
//    
//    func checkAndMaintainDisk(_ deviceId: String) {
//        // Throttle to ~hourly per device
//        let now = Date().timeIntervalSince1970
//        let key = diskCheckKey + ".\(deviceId)"
//        let last = defaults.double(forKey: key)
//        if now - last < 3600 { return }
//        defaults.set(now, forKey: key)
//        
//        api.getDiskSpace(deviceId) // Single<PolarDiskSpaceData>
//            .observe(on: MainScheduler.instance)
//            .subscribe(onSuccess: { [weak self] ds in
//                guard let self = self else { return }
//                
//                // Try to pull (used,total) robustly across SDK versions
//                guard let (used, total) = PolarManager.unpackDiskSpace(ds) else {
//                    NSLog("[PM] getDiskSpace: could not extract fields for \(deviceId)")
//                    return
//                }
//                
//                let pct = Double(used) / max(1.0, Double(total))
//                NSLog("[PM] disk space used=\(used)/\(total) (\(Int(pct * 100))%) for \(deviceId)")
//                
//                if pct >= PolarManager.diskPressureThreshold {
//                    // Ingest everything we can (per-entry cleanup happens after ingest)
//                    self.listAndDownload360Offline(deviceId)
//                }
//            }, onFailure: { err in
//                print("getDiskSpace error:", err)
//            })
//            .disposed(by: disposeBag)
//    }
//    
//    func clearOfflineRecord(deviceId: String, entry: PolarOfflineRecordingEntry) {
//        api.removeOfflineRecord(deviceId, entry: entry)
//            .subscribe(onCompleted: {
//                NSLog("[PM] cleared offline entry \(entry) for \(deviceId)")
//            }, onError: { err in
//                print("removeOfflineRecord error:", err)
//            })
//            .disposed(by: disposeBag)
//    }
//}
//
//extension Notification.Name {
//    static let ctRequestPolarDailySync = Notification.Name("ct.request.polar.dailySync")
//}
//
//private extension PolarManager {
//    func triggerPolar360DailySync(_ deviceId: String) {
//        NotificationCenter.default.post(name: .ctRequestPolarDailySync, object: nil, userInfo: ["deviceId": deviceId])
//    }
//}
//
//private extension PolarManager {
//    /// Reflection-based extractor so we don't depend on exact SDK field names.
//    /// Tries common variants: used/usedBytes/bytesUsed, total/totalBytes/bytesTotal, free/freeBytes/bytesFree.
//    static func unpackDiskSpace(_ disk: Any) -> (used: UInt64, total: UInt64)? {
//        let m = Mirror(reflecting: disk)
//        var used: UInt64?
//        var total: UInt64?
//        var free: UInt64?
//        
//        for child in m.children {
//            guard let label = child.label else { continue }
//            switch label {
//            case "used", "usedBytes", "bytesUsed":
//                used = child.value as? UInt64
//            case "total", "totalBytes", "bytesTotal":
//                total = child.value as? UInt64
//            case "free", "freeBytes", "bytesFree":
//                free = child.value as? UInt64
//            default:
//                break
//            }
//        }
//        
//        if let u = used, let t = total { return (u, t) }
//        if let f = free, let t = total, t >= f { return (t &- f, t) } // &- avoids overflow trap
//        return nil
//    }
//}
//
//// MARK: - Diagnostics: Offline Recording health
//
//extension PolarManager {
//    /// Call this right after connect (and anytime you want to inspect state).
//    func verifyOfflineRecordingHealth(_ deviceId: String) {
//        // 1) Is feature even ready on this device?
//        let ready = api.isFeatureReady(deviceId, feature: .feature_polar_offline_recording)
//        NSLog("[PM] offline feature ready: \(ready) for \(deviceId)")
//        
//        // 2) Try listing entries; if none, recording likely not started
//        api.listOfflineRecordings(deviceId)
//            .toArray() // Single<[PolarOfflineRecordingEntry]>
//            .observe(on: MainScheduler.instance)
//            .subscribe(onSuccess: { entries in
//                NSLog("[PM] offline entries count=\(entries.count) for \(deviceId)")
//                for e in entries {
//                    NSLog("[PM] entry: \(e)")
//                }
//            }, onFailure: { err in
//                print("[PM] listOfflineRecordings error:", err)
//            })
//            .disposed(by: disposeBag)
//    }
//    
//    // MARK: - Ordered offline pipeline
//    
//    private func ensureOfflinePipeline(for deviceId: String) {
//        // Avoid parallel starts
//        if offlineStartInFlight.contains(deviceId) { return }
//        offlineStartInFlight.insert(deviceId)
//        
//        // 1) Ensure offline PPG is running (treat "Already in state" as success)
//        start360OfflinePpg(deviceId) { [weak self] started in
//            guard let self = self else { return }
//            self.offlineStartInFlight.remove(deviceId)
//            if started { self.offlineActive.insert(deviceId) }
//            
//            // 2) Light disk guard (once per hour via your throttle)
//            self.checkAndMaintainDisk(deviceId)
//            
//            // 3) Backfill any buffered records (with retry/backoff inside)
//            self.listAndDownload360Offline(deviceId)
//            
//            // 4) Ask the daily sync layer to fetch steps/sleep packets
//            self.triggerPolar360DailySync(deviceId)
//            
//            // 5) Optional: log health so you can see state in console
//            self.verifyOfflineRecordingHealth(deviceId)
//        }
//    }
//    
//}
//
//private extension PolarManager {
//    static func extractSampleRateHz(from setting: PolarSensorSetting) -> Int? {
//        // Newer SDKs: .sampleRate key with Int values
//        if let values = setting.settings[.sampleRate], let v = values.first, v > 0 {
//            return Int(v)
//        }
//        // Fallbacks (older SDKs occasionally expose as NSNumber/UInt)
//        if let values = setting.settings[.sampleRate], let num = values.first as? NSNumber {
//            let v = num.intValue
//            return (v > 0) ? v : nil
//        }
//        return nil
//    }
//    
//    static func extractChannels(from setting: PolarSensorSetting) -> Int? {
//        if let values = setting.settings[.channels], let v = values.first, v > 0 {
//            return Int(v)
//        }
//        if let values = setting.settings[.channels], let num = values.first as? NSNumber {
//            let v = num.intValue
//            return (v > 0) ? v : nil
//        }
//        return nil
//    }
//}
//
//extension PolarManager {
//    func appDidEnterBackground(onStabilized: @escaping () -> Void) {
//        // Don’t stop streams here. Just mark and run a quick health check on a background-safe queue.
//        pendingBgCompletion = onStabilized
//        lastBgAt = Date()
//        
//        // If you accidentally background without BLE mode, warn once (dev-only)
//#if DEBUG
//        if !Self._hasBluetoothCentralBackgroundMode() {
//            NSLog("[PM] ⚠️ UIBackgroundModes bluetooth-central is NOT enabled. Background streaming will suspend.")
//        }
//#endif
//        
//        // Minimal work: confirm we still have active disposables or re-arm intent flags.
//        // No heavy networking here; let the OS coalesce.
//        if case .connected(let dev) = connectionState {
//            // make sure our desired streams are still desired/armed
//            if ppiStartDesired && ppiStreamDisposable == nil && !isPpiStarting {
//                // don’t actually start here; just leave desire true. The FG hook will re-verify.
//            }
//            // HR stream should already be active; do nothing unless it failed below.
//        }
//        
//        // hand control back quickly; the OS may give ~10–30s background time total
//        pendingBgCompletion?()
//        pendingBgCompletion = nil
//    }
//    
//    /// Called from AppDelegate.applicationWillEnterForeground
//    func appWillEnterForeground() {
//        // Light sanity checks. Avoid duplicate starts.
//        guard case .connected(let dev) = connectionState else { return }
//        
//        // If HR/RR were disposed by the system, re-try them.
//        if hrStreamDisposable == nil {
//            startHrStreamingIfPossible(for: dev)
//        }
//        if ppiStartDesired && ppiStreamDisposable == nil && !isPpiStarting {
//            maybeStartPpiWhenReady(for: dev)
//        }
//        
//        if let dev = connectedDevice {
//            PolarDailySyncCoordinator.shared.fetchTodayAndYesterday(deviceId: dev.id)
//        }
//        
//        // Opportunistically refresh snapshot (battery/firmware) for UI
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//            self.broadcastSnapshotIfCurrent()
//        }
//    }
//    
//    private static func _hasBluetoothCentralBackgroundMode() -> Bool {
//        guard let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] else { return false }
//        return modes.contains("bluetooth-central")
//    }
//}
//
//
//// MARK: - Device Controls & Sync (SDK-parity)
//extension PolarManager { // Device Controls & Sync
//    
//    /// Sends a factory reset command to the connected device.
//    /// - Parameter preservePairing: If true, the device preserves pairing info (when supported).
//    func factoryReset(preservePairing: Bool = true, onComplete: ((Swift.Result<Void, Error>) -> Void)? = nil) {
//        guard let dev = connectedDevice else {
//            NSLog("[PM] factoryReset: no connected device")
//            onComplete?(.failure(NSError(domain: "PolarManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No device connected"])))
//            return
//        }
//        Task.detached { [weak self] in
//            do {
//                _ = try await self?.api.doFactoryReset(dev.id, preservePairingInformation: preservePairing).value
//                NSLog("[PM] factory reset sent to %@", dev.id)
//                onComplete?(.success(()))
//            } catch {
//                NSLog("[PM] factoryReset error: %@", String(describing: error))
//                onComplete?(.failure(error))
//            }
//        }
//    }
//    
//    /// Turns the device off (supported devices only).
//    func turnOff(onComplete: ((Swift.Result<Void, Error>) -> Void)? = nil) {
//        guard let dev = connectedDevice else {
//            NSLog("[PM] turnOff: no connected device")
//            onComplete?(.failure(NSError(domain: "PolarManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No device connected"])))
//            return
//        }
//        Task.detached { [weak self] in
//            do {
//                _ = try await self?.api.turnDeviceOff(dev.id).value
//                NSLog("[PM] turnOff sent to %@", dev.id)
//                onComplete?(.success(()))
//            } catch {
//                NSLog("[PM] turnOff error: %@", String(describing: error))
//                onComplete?(.failure(error))
//            }
//        }
//    }
//    
//    /// Restarts the device (supported devices only).
//    /// On some devices a GATT disconnect after the command is expected.
//    func restart(preservePairing: Bool = true, onComplete: ((Swift.Result<Void, Error>) -> Void)? = nil) {
//        guard let dev = connectedDevice else {
//            NSLog("[PM] restart: no connected device")
//            onComplete?(.failure(NSError(domain: "PolarManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No device connected"])))
//            return
//        }
//        Task.detached { [weak self] in
//            do {
//                _ = try await self?.api.doRestart(dev.id, preservePairingInformation: preservePairing).value
//                NSLog("[PM] restart sent to %@", dev.id)
//                onComplete?(.success(()))
//            } catch {
//                let lower = String(describing: error).lowercased()
//                if lower.contains("gattdisconnected") {
//                    NSLog("[PM] restart: gattDisconnected observed (expected on some devices)")
//                    onComplete?(.success(()))
//                } else {
//                    NSLog("[PM] restart error: %@", String(describing: error))
//                    onComplete?(.failure(error))
//                }
//            }
//        }
//    }
//    
//    /// Sets the device's local time (and timezone).
//    func setLocalTime(_ time: Date = Date(), zone: TimeZone = .current, onComplete: ((Swift.Result<Void, Error>) -> Void)? = nil) {
//        guard let dev = connectedDevice else {
//            NSLog("[PM] setLocalTime: no connected device")
//            onComplete?(.failure(NSError(domain: "PolarManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No device connected"])))
//            return
//        }
//        Task.detached { [weak self] in
//            do {
//                _ = try await self?.api.setLocalTime(dev.id, time: time, zone: zone).value
//                NSLog("[PM] setLocalTime success for %@ -> %@ %@", dev.id, time as NSDate, zone.identifier)
//                onComplete?(.success(()))
//            } catch {
//                NSLog("[PM] setLocalTime error: %@", String(describing: error))
//                onComplete?(.failure(error))
//            }
//        }
//    }
//    
//    /// Reads the device's local time.
//    func getLocalTime(onComplete: @escaping (Swift.Result<Date, Error>) -> Void) {
//        guard let dev = connectedDevice else {
//            NSLog("[PM] getLocalTime: no connected device")
//            onComplete(.failure(NSError(domain: "PolarManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No device connected"])))
//            return
//        }
//        Task.detached { [weak self] in
//            do {
//                let date: Date = try await self!.api.getLocalTime(dev.id).value
//                NSLog("[PM] getLocalTime success for %@ -> %@", dev.id, date as NSDate)
//                onComplete(.success(date))
//            } catch {
//                NSLog("[PM] getLocalTime error: %@", String(describing: error))
//                onComplete(.failure(error))
//            }
//        }
//    }
//    
//    /// Puts device into warehouse sleep (supported devices only).
//    func setWarehouseSleep(onComplete: ((Swift.Result<Void, Error>) -> Void)? = nil) {
//        guard let dev = connectedDevice else {
//            NSLog("[PM] setWarehouseSleep: no connected device")
//            onComplete?(.failure(NSError(domain: "PolarManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No device connected"])))
//            return
//        }
//        Task.detached { [weak self] in
//            do {
//                _ = try await self?.api.setWarehouseSleep(dev.id).value
//                NSLog("[PM] setWarehouseSleep sent to %@", dev.id)
//                onComplete?(.success(()))
//            } catch {
//                NSLog("[PM] setWarehouseSleep error: %@", String(describing: error))
//                onComplete?(.failure(error))
//            }
//        }
//    }
//    
//    /// Triggers your full, ordered offline pipeline once, on demand.
//    /// Safe to call repeatedly; internal guards prevent parallel starts.
//    func syncNow() {
//        guard let dev = connectedDevice else {
//            NSLog("[PM] syncNow: no connected device")
//            return
//        }
//        ensureOfflinePipeline(for: dev.id)
//    }
//}
//
//extension PolarManager {
//    /// Polar device-management commands (turn off, restart, factory reset) are exposed behind this feature.
//    func supportsDeviceManagement(_ deviceId: String) -> Bool {
//        api.isFeatureReady(deviceId, feature: .feature_polar_features_configuration_service)
//    }
//    func supportsTurnOff(_ deviceId: String) -> Bool { supportsDeviceManagement(deviceId) }
//    func supportsFactoryReset(_ deviceId: String) -> Bool { supportsDeviceManagement(deviceId) }
//}
//
//// PolarManager.swift (extension)
//extension PolarManager {
//
//    /// Upsert daily rollup (optional — UI should still use per-minute merged view).
//    func submitPolar360DailyActivity(date: Date, steps: Int, distanceMeters: Double? = nil, calories: Double? = nil) {
//        CTMetricsRepository.shared.upsert(kind: .steps,
//                                          value: Double(steps),
//                                          unit: "steps",
//                                          source: .polar360,
//                                          date: date)
//        NotificationCenter.default.post(name: .ctMetricUpdated, object: nil,
//                                        userInfo: ["kind": "steps", "date": date])
//    }
//}
