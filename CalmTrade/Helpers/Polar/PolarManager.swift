//
//  PolarManager.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/09/25.
//

import Foundation
import PolarBleSdk
import CoreBluetooth
import RxSwift
import UIKit
import os.log

// MARK: - Firmware Notifications

extension Notification.Name {
    static let ctFwCheck = Notification.Name("ct.fw.check")
    static let ctFwProgress = Notification.Name("ct.fw.progress")
}

// MARK: - Models

struct ScannedPolarDevice: Hashable {
    let polarInfo: PolarDeviceInfo
    var id: String { polarInfo.deviceId }
    var name: String {
        polarInfo.name
            .replacingOccurrences(of: polarInfo.deviceId, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ScannedPolarDevice, rhs: ScannedPolarDevice) -> Bool { lhs.id == rhs.id }
}

struct PolarDeviceSnapshot {
    let id: String
    let name: String
    let firmware: String?
    let batteryLevel: UInt?
    let charging: Bool?
    let timestamp: Date
}

struct FirmwareProgress {
    let stage: String
    let detail: String?
    let fraction: Double?
}

// MARK: - Main Manager Class

final class PolarManager: NSObject,
                          PolarBleApiObserver,
                          PolarBleApiDeviceInfoObserver,
                          PolarBleApiDeviceHrObserver,
                          PolarBleApiDeviceFeaturesObserver {

    // MARK: - Singleton

    static let shared = PolarManager()

    // MARK: - User Defaults (auto reconnect)

    let defaults = UserDefaults.standard
    let lastDeviceIdKey   = "ct.polar.lastDeviceId"
    let lastDeviceNameKey = "ct.polar.lastDeviceName"

    var reconnectRetryWork: DispatchWorkItem?
    var isAutoReconnectInFlight = false

    // Track when we were last disconnected to help with reconnection logic
    var lastDisconnectTime: Date?

    var lastBatteryLevel: UInt?
    var lastFirmwareVersion: String?
    var lastChargingState: BleBasClient.ChargeState?

    // MARK: - Callbacks

    var onDevicesUpdated: (([ScannedPolarDevice]) -> Void)?
    var onDeviceDiscovered: ((ScannedPolarDevice) -> Void)?
    var onConnectionStateChanged: ((ConnectionState) -> Void)?
    var connectionObservers: [UUID: (ConnectionState) -> Void] = [:]

    var onFwCheck: ((CheckFirmwareUpdateStatus) -> Void)?
    var onFwStatus: ((FirmwareUpdateStatus) -> Void)?
    var onFwError: ((Error) -> Void)?

    var onHeartRate: ((Double, Date) -> Void)?
    var onRRIntervals: (([Int], Date) -> Void)?

    var onH10ExerciseEntry: ((PolarExerciseEntry) -> Void)?
    var onH10ExerciseData: ((PolarExerciseData) -> Void)?
    var on360OfflineEntry: ((PolarOfflineRecordingEntry) -> Void)?
    var on360OfflinePpg: ((PolarPpgData, Date) -> Void)?

    var onSnapshot: ((PolarDeviceSnapshot) -> Void)?
    var onBatteryUpdate: ((String, UInt, Bool?) -> Void)?

    var onRHRComputed: ((Double, CTMetricSource, String) -> Void)?
    var onOfflinePpgIngested: ((Date, Int) -> Void)?
    var sleepRecordingObservers: [UUID: (Bool, Bool) -> Void] = [:]

    var pendingBgCompletion: (() -> Void)?
    var lastBgAt: Date?

    // MARK: - Public State

    enum ConnectionState {
        case disconnected
        case connecting(ScannedPolarDevice)
        case connected(ScannedPolarDevice)
    }

    public /*private(set)*/ var discoveredDevices = Set<ScannedPolarDevice>()
    public /*private(set)*/ var connectionState: ConnectionState = .disconnected {
        didSet {
            onConnectionStateChanged?(connectionState)
            for cb in connectionObservers.values { cb(connectionState) }
        }
    }
    public /*private(set)*/ var connectedDevice: ScannedPolarDevice?
    public /*private(set)*/ var connectingDevice: ScannedPolarDevice?

    // MARK: - FTU Callbacks

    var onFirstTimeUseNeeded: ((ScannedPolarDevice) -> Void)?
    var onFtuProgress: ((String) -> Void)?
    var onFtuCompleted: (() -> Void)?
    var onFtuError: ((Error) -> Void)?

    var ftuEvalPendingDeviceId: String?
    var ftuEvalRetryCount = 0
    let ftuEvalRetryMax = 6

    var currentIdentifier: String? { connectedDevice?.id }

    // MARK: - SDK + Disposables

    var api: PolarBleApi!
    var searchDisposable: Disposable?
    var fwDisposable: Disposable?
    var sleepRecordingDisposable: Disposable?
    var hrStreamDisposable: Disposable?
    var ppiStreamDisposable: Disposable?
    var ecgStreamDisposable: Disposable?
    var ppgStreamDisposable: Disposable?

    let disposeBag = DisposeBag()

    var fwRetryCount = 0
    let fwMaxRetries = 3

    var isHrReady = false
    var hrStartRetry = 0

    // Use self as delegate so BT on/off transitions are observed.
    lazy var central: CBCentralManager = {
        CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: false
        ])
    }()

    var isShowingBluetoothAlert = false
    var lastBluetoothAlertAt: Date?

    var streamingFeatureArmedAt: Date?
    var isPpiStarting = false
    var ppiStartRetry = 0
    var ppiStartDesired = false
    private(set) var sleepRecordingState: (available: Bool, enabled: Bool) = (false, false) {
        didSet {
            guard oldValue != sleepRecordingState else { return }
            NSLog("[PM][SLEEP] recording state changed available=\(sleepRecordingState.available) enabled=\(sleepRecordingState.enabled)")
            for cb in sleepRecordingObservers.values {
                cb(sleepRecordingState.available, sleepRecordingState.enabled)
            }
        }
    }

    var offlineStartInFlight = Set<String>()
    var offlineActive        = Set<String>()
    var shouldResumeSearchAfterBluetoothOn = false

    let firstUseKeyPrefix = "ct.polar.firstUse."
    var autoOfflineSyncOnConnect: Bool = true

    let fwLog = OSLog(subsystem: "CalmTrade", category: "Firmware")
    var isFwUpdatingInternal = false

    // MARK: - Init

    private override init() {
        super.init()

        api = PolarBleApiDefaultImpl.polarImplementation(
            DispatchQueue.main,
            features: [
                .feature_hr,
                .feature_polar_online_streaming,
                .feature_battery_info,
                .feature_device_info,
                .feature_polar_firmware_update,
                .feature_polar_features_configuration_service,
                .feature_polar_sdk_mode,
                .feature_polar_device_time_setup,
                .feature_polar_activity_data,
                .feature_polar_offline_recording,
                .feature_polar_h10_exercise_recording
            ]
        )

        api.observer = self
        api.deviceInfoObserver = self
        api.deviceHrObserver = self
        api.deviceFeaturesObserver = self
    }
}

// MARK: - PolarBleApiDeviceListener & Feature Observer

extension PolarManager {

    func deviceConnecting(_ info: PolarDeviceInfo) {
        isAutoReconnectInFlight = false
        let dev = ScannedPolarDevice(polarInfo: info)
        connectingDevice = dev
        connectionState = .connecting(dev)
    }

    func deviceConnected(_ info: PolarDeviceInfo) {
        let dev = ScannedPolarDevice(polarInfo: info)
        connectedDevice = dev
        connectingDevice = nil
        connectionState = .connected(dev)
        NSLog("[PM] deviceConnected id=\(dev.id) name=\(dev.name)")
        
        NSLog("[PM] deviceConnected → arming FTU")
        armFtuEvaluation(for: dev)
        
        let lowered = dev.name.lowercased()
        DeviceManager.shared.currentSource = lowered.contains("h10") ? .polarH10 : .polar360

        defaults.set(dev.id,   forKey: lastDeviceIdKey)
        defaults.set(dev.name, forKey: lastDeviceNameKey)

        // Kick readiness gate (will also trigger offline sync in waitForConnection)
        waitForConnection(deviceId: dev.id)

        isHrReady = false
        hrStartRetry = 0
        ppiStartDesired = false
        offlineStartInFlight.remove(dev.id)
        setLocalTimeNow()
        startObservingSleepRecordingState()

        NSLog("[PM] connected; waiting for DIS callbacks (firmware/software revision)")
        broadcastSnapshotIfCurrent()

        // Force immediate steps sync when connecting to Polar device
        PolarDailySyncCoordinator.shared.fetchTodayAndYesterday(deviceId: dev.id)
        
        // Sleep sync will be triggered when activity feature becomes ready
        // This ensures that the device is fully ready before attempting to fetch sleep data
        NSLog("[PM] Sleep sync scheduled for when activity feature is ready")
        
        PolarDailySyncCoordinator.shared.startWhileConnected(deviceId: dev.id)
    }

    func deviceDisconnected(_ identifier: PolarDeviceInfo, pairingError: Bool) {
        isAutoReconnectInFlight = false
        connectedDevice = nil
        connectingDevice = nil
        connectionState = .disconnected
        DeviceManager.shared.currentSource = .appleHealthKit
        stopAllStreaming()
        PolarDailySyncCoordinator.shared.stop()
        
        // reset streaming guards
        streamingFeatureArmedAt = nil
        isPpiStarting = false
        ppiStartRetry = 0
        isHrReady = false
        hrStartRetry = 0
        stopObservingSleepRecordingState()
    }

    func hrValueReceived(_ identifier: String,
                         data: (hr: UInt8, rrs: [Int], rrsMs: [Int],
                                contact: Bool, contactSupported: Bool)) {
        // Only skip when explicit HR streaming is already active.
        if hrStreamDisposable != nil { return }
        if data.contactSupported && !data.contact { return }
        
        let ts = Date()
        onHeartRate?(Double(data.hr), ts)
        
        if !data.rrsMs.isEmpty {
            debugPrint("=== POLAR RR INTERVALS RECEIVED ===")
            debugPrint("RR intervals (ms): \(data.rrsMs.map { Int($0) })")
            debugPrint("RR count: \(data.rrsMs.count)")
            debugPrint("Timestamp: \(ts)")
            debugPrint("==================================")
            onRRIntervals?(data.rrsMs.map { Int($0) }, ts)
        } else if !data.rrs.isEmpty {
            let rrMs = data.rrs.map { Int((Double($0) / 1024.0) * 1000.0) }
            debugPrint("=== POLAR RR INTERVALS RECEIVED (converted) ===")
            debugPrint("Original RR values: \(data.rrs)")
            debugPrint("Converted RR intervals (ms): \(rrMs)")
            debugPrint("RR count: \(rrMs.count)")
            debugPrint("Timestamp: \(ts)")
            debugPrint("=============================================")
            onRRIntervals?(rrMs, ts)
        } else {
            debugPrint("=== POLAR HR DATA ONLY ===")
            debugPrint("Only heart rate received: \(data.hr) BPM")
            debugPrint("No RR intervals available")
            debugPrint("Timestamp: \(ts)")
            debugPrint("========================")
        }
    }

    // MARK: - Test Functions
    func testRRIntervalFlow() {
        debugPrint("=== TESTING RR INTERVAL FLOW ===")
        debugPrint("Simulating RR intervals: [1000, 980, 1020, 990, 1010, 970, 1030]")
        debugPrint("These represent RR intervals in milliseconds")
        debugPrint("Expected BPM conversions: [60, 61.2, 58.8, 60.6, 59.4, 61.9, 58.3]")
        debugPrint("================================")

        // Simulate receiving RR intervals from Polar device
        let simulatedRRIntervals: [Int] = [1000, 980, 1020, 990, 1010, 970, 1030] // in milliseconds
        let timestamp = Date()

        debugPrint("Testing LiveDataRouter flow (HRV metrics)...")
        // This should trigger the LiveDataRouter flow for HRV metrics
        onRRIntervals?(simulatedRRIntervals, timestamp)

        debugPrint("Testing RHR calculation flow...")
        // Also test the RHR calculation directly
        computeRestingHeartRate(from: simulatedRRIntervals, source: .polar360, deviceId: "TEST_DEVICE")

        debugPrint("Test completed. Check for both HRV and RHR computation messages above.")
        debugPrint("================================")
    }

    func testStaticRHRFlow() {
        debugPrint("=== TESTING STATIC RHR CALCULATION ===")
        debugPrint("Using static RR intervals representing a person at rest")
        debugPrint("Typical resting RR intervals: [1100, 1080, 1120, 1090, 1110, 1070, 1130, 1085, 1115, 1095]")
        debugPrint("These convert to BPM: [54.5, 55.6, 53.6, 55.0, 54.1, 55.9, 53.1, 55.3, 54.2, 54.8]")
        debugPrint("Expected median RHR: ~54.5-55 BPM")
        debugPrint("================================")

        // Static data representing typical resting heart rate
        let staticRRIntervals: [Int] = [1100, 1080, 1120, 1090, 1110, 1070, 1130, 1085, 1115, 1095]

        debugPrint("Calculating RHR from static data...")
        computeRestingHeartRate(from: staticRRIntervals, source: .polar360, deviceId: "STATIC_TEST")

        debugPrint("Static RHR test completed.")
        debugPrint("================================")
    }

    func bleSdkFeatureReady(_ identifier: String, feature: PolarBleSdkFeature) {
        guard identifier == connectedDevice?.id else { return }

        switch feature {
        case .feature_polar_online_streaming:
            let now = Date()
            if let last = streamingFeatureArmedAt, now.timeIntervalSince(last) < 1.0 { return }
            streamingFeatureArmedAt = now
            
            guard let dev = connectedDevice else { return }
            // Resume HR if applicable
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.startHrStreamingIfPossible(for: dev)
            }
            
            // Only *request* PPI here; the helper will verify readiness and start once stable
            let name = dev.name.lowercased()
            let isOptical = name.contains("360") || name.contains("verity") || name.contains("oh1")
            if isOptical || self.ppiStartDesired {
                self.ppiStartDesired = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self.maybeStartPpiWhenReady(for: dev)
                }
            }
            
        case .feature_polar_offline_recording:
            // Don’t call start/list directly; just ensure the ordered pipeline runs
            ensureOfflinePipeline(for: identifier)
            
        case .feature_polar_features_configuration_service:
            NSLog("[PM][FTU] CFG feature became ready; evaluating FTU now")
            maybeEvaluateFTU(reason: "feature-ready-callback")

        case .feature_polar_device_time_setup:
            setLocalTimeNow(identifier)
            
        case .feature_polar_activity_data:
                NSLog("[PM][ACT] Activity feature ready — starting minute poller")
                PolarDailySyncCoordinator.shared.startWhileConnected(deviceId: identifier)
                
                // Only trigger sleep sync after FTU is confirmed complete.
                Task { [weak self] in
                    guard let self else { return }
                    let isFtuDone = await self.isFtuCompleteForCurrentDevice()
                    if isFtuDone {
                        NSLog("[PM][SLEEP] Activity feature ready — FTU complete, triggering sleep sync")
                        Polar360SleepIngestor.shared.syncLastNightsIfNeeded(deviceId: identifier)
                    } else {
                        NSLog("[PM][SLEEP] Activity feature ready — FTU incomplete, skipping sleep sync")
                    }
                }
            
        default:
            break
        }
        
        if feature == .feature_polar_online_streaming ||
            feature == .feature_device_info ||
            feature == .feature_polar_features_configuration_service {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.probeFtuStatus(reason: "feature-ready:\(feature)")
            }
        }
    }
}

extension Notification.Name {
    static let ctRequestPolarDailySync = Notification.Name("ct.request.polar.dailySync")
}

// MARK: - Capability checks

extension PolarManager {

    func isRealtime360SyncAllowed() -> Bool {
        switch FeatureGate.shared.access(for: FeatureKey.realtime360Sync) {
        case .allowed:
            return true
        case .locked:
            return false
        }
    }

    func supportsDeviceManagement(_ deviceId: String) -> Bool {
        api.isFeatureReady(deviceId, feature: .feature_polar_features_configuration_service)
    }
    
    /// Whether the connected device supports the BLE "turn-off" command.
    func supportsTurnOff(_ deviceId: String) -> Bool { supportsDeviceManagement(deviceId) }

    /// Whether the connected device supports factory reset.
    func supportsFactoryReset(_ deviceId: String) -> Bool { supportsDeviceManagement(deviceId) }

    // MARK: - Public Test Method
    public func runRRIntervalTests() {
        testRRIntervalFlow()
        testStaticRHRFlow()
    }
    
    // MARK: - Public Sleep Sync Method
    public func syncSleepData(for deviceId: String, from: Date, to: Date) {
        NSLog("[PM][SLEEP] Manual sleep sync triggered for device \(deviceId)")
        Polar360SleepIngestor.shared.fetchSleepDataForDateRange(
            deviceId: deviceId,
            from: from,
            to: to
        ) { result in
            switch result {
            case .success(let message):
                NSLog("[PM][SLEEP] Sleep sync successful: \(message)")
            case .failure(let error):
                NSLog("[PM][SLEEP] Sleep sync failed: \(error.localizedDescription)")
            }
        }
    }

    @discardableResult
    func addSleepRecordingObserver(_ block: @escaping (Bool, Bool) -> Void) -> UUID {
        let id = UUID()
        sleepRecordingObservers[id] = block
        block(sleepRecordingState.available, sleepRecordingState.enabled)
        return id
    }

    func removeSleepRecordingObserver(_ id: UUID) {
        sleepRecordingObservers.removeValue(forKey: id)
    }

    func startObservingSleepRecordingState() {
        guard let deviceId = currentIdentifier else {
            updateSleepRecordingState(available: false, enabled: false)
            return
        }

        sleepRecordingDisposable?.dispose()
        sleepRecordingDisposable = api.observeSleepRecordingState(identifier: deviceId)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onNext: { [weak self] enabledValues in
                    guard let enabled = enabledValues.last else { return }
                    self?.updateSleepRecordingState(available: true, enabled: enabled)
                },
                onError: { [weak self] error in
                    NSLog("[PM][SLEEP] observe sleep recording state failed: %@", error.localizedDescription)
                    self?.updateSleepRecordingState(available: false, enabled: false)
                }
            )

        refreshSleepRecordingState()
    }

    func refreshSleepRecordingState() {
        guard let deviceId = currentIdentifier else {
            updateSleepRecordingState(available: false, enabled: false)
            return
        }

        api.getSleepRecordingState(identifier: deviceId)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onSuccess: { [weak self] enabled in
                    self?.updateSleepRecordingState(available: true, enabled: enabled)
                },
                onFailure: { [weak self] error in
                    NSLog("[PM][SLEEP] get sleep recording state failed: %@", error.localizedDescription)
                    self?.updateSleepRecordingState(available: false, enabled: false)
                }
            )
            .disposed(by: disposeBag)
    }

    func stopSleepRecording(completion: ((Swift.Result<Void, Error>) -> Void)? = nil) {
        guard let deviceId = currentIdentifier else {
            let error = NSError(
                domain: "PolarManager.SleepRecording",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No Polar device connected"]
            )
            completion?(.failure(error))
            return
        }

        api.stopSleepRecording(identifier: deviceId)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onCompleted: { [weak self] in
                    NSLog("[PM][SLEEP] stop sleep recording completed")
                    self?.refreshSleepRecordingState()
                    completion?(.success(()))
                },
                onError: { error in
                    NSLog("[PM][SLEEP] stop sleep recording failed: %@", error.localizedDescription)
                    completion?(.failure(error))
                }
            )
            .disposed(by: disposeBag)
    }

    func maybeStopSleepRecordingAfterSuccessfulFetch(for deviceId: String) {
        guard currentIdentifier == deviceId else {
            NSLog("[PM][SLEEP] skip auto-stop; fetched device %@ is not the active connected device", deviceId)
            return
        }

        let stopIfNeeded: (Bool) -> Void = { [weak self] isEnabled in
            guard let self else { return }
            guard isEnabled else {
                NSLog("[PM][SLEEP] auto-stop skipped; recording already off")
                return
            }

            self.stopSleepRecording { result in
                switch result {
                case .success:
                    NSLog("[PM][SLEEP] auto-stop after fetch succeeded")
                case .failure(let error):
                    NSLog("[PM][SLEEP] auto-stop after fetch failed: %@", error.localizedDescription)
                }
            }
        }

        if sleepRecordingState.available {
            stopIfNeeded(sleepRecordingState.enabled)
            return
        }

        api.getSleepRecordingState(identifier: deviceId)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onSuccess: { [weak self] enabled in
                    self?.updateSleepRecordingState(available: true, enabled: enabled)
                    stopIfNeeded(enabled)
                },
                onFailure: { error in
                    NSLog("[PM][SLEEP] auto-stop state check failed: %@", error.localizedDescription)
                }
            )
            .disposed(by: disposeBag)
    }

    private func stopObservingSleepRecordingState() {
        sleepRecordingDisposable?.dispose()
        sleepRecordingDisposable = nil
        updateSleepRecordingState(available: false, enabled: false)
    }

    private func updateSleepRecordingState(available: Bool, enabled: Bool) {
        sleepRecordingState = (available, enabled)
    }
}
