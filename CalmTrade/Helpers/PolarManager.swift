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

/// A simple, hashable wrapper for the device info provided by the Polar SDK.
/// This prevents name collisions and helps manage discovered devices in a Set.
struct ScannedPolarDevice: Hashable {
    let polarInfo: PolarDeviceInfo
    
    var id: String { polarInfo.deviceId }
    var name: String { polarInfo.name }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ScannedPolarDevice, rhs: ScannedPolarDevice) -> Bool {
        return lhs.id == rhs.id
    }
}

/// A singleton class to manage all Polar device operations.
class PolarManager: NSObject, PolarBleApiObserver, PolarBleApiDeviceInfoObserver {
    func batteryChargingStatusReceived(_ identifier: String, chargingStatus: PolarBleSdk.BleBasClient.ChargeState) {
        
    }
    
    func disInformationReceivedWithKeysAsStrings(_ identifier: String, key: String, value: String) {
        
    }
    
    
    static let shared = PolarManager()
    
    private var searchDisposable: Disposable?
    
    enum ConnectionState {
        case disconnected
        case connecting(ScannedPolarDevice)
        case connected(ScannedPolarDevice)
    }
    
    // MARK: - Public State & Bindings
    
    private(set) var discoveredDevices = Set<ScannedPolarDevice>()
    private(set) var connectionState: ConnectionState = .disconnected
    
    var onDevicesUpdated: (([ScannedPolarDevice]) -> Void)?
    var onConnectionStateChanged: ((ConnectionState) -> Void)?
    
    // MARK: - Private Properties
    private var api: PolarBleApi!
    private let disposeBag = DisposeBag()
    
    private override init() {
        super.init()
        // **FIX**: Correctly initialize the Polar BLE API with proper parameter labels and features.
        api = PolarBleApiDefaultImpl.polarImplementation(DispatchQueue.main, features: [
            PolarBleSdkFeature.feature_hr,
            PolarBleSdkFeature.feature_polar_online_streaming,
            PolarBleSdkFeature.feature_battery_info,
            PolarBleSdkFeature.feature_device_info
        ])
        api.observer = self
        api.deviceInfoObserver = self
    }
    
    // MARK: - Public Methods
    
    func startDeviceSearch() {
        print("PolarManager: Starting device search...")
        stopDeviceSearch()
        
        discoveredDevices.removeAll()
        onDevicesUpdated?(Array(discoveredDevices))
        
        searchDisposable = api.searchForDevice()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] sdkDevice in
                let newDevice = ScannedPolarDevice(polarInfo: sdkDevice)
                if self?.discoveredDevices.contains(newDevice) == false {
                    self?.discoveredDevices.insert(newDevice)
                    self?.onDevicesUpdated?(Array(self!.discoveredDevices).sorted(by: { $0.name < $1.name }))
                }
            }, onError: { error in
                print("PolarManager: Device search error: \(error)")
            })
    }
    
    func stopDeviceSearch() {
        print("PolarManager: Stopping device search.")
        searchDisposable?.dispose()
        searchDisposable = nil
    }
    
    func connect(to device: ScannedPolarDevice) {
        print("PolarManager: Attempting to connect to \(device.name)...")
        do {
            try api.connectToDevice(device.id)
            connectionState = .connecting(device)
            onConnectionStateChanged?(connectionState)
        } catch let err {
            print("PolarManager: Failed to start connection to \(device.id). Error: \(err)")
        }
    }
    
    func disconnect() {
        guard case .connected(let device) = connectionState else { return }
        do {
            try api.disconnectFromDevice(device.id)
        } catch let err {
            print("PolarManager: Failed to disconnect from \(device.id). Error: \(err)")
        }
    }
    
    // MARK: - PolarBleApiObserver (Connection Lifecycle)
    
    func deviceConnecting(_ sdkDeviceInfo: PolarDeviceInfo) {
        print("Polar SDK state: Connecting to \(sdkDeviceInfo.name)")
        let device = ScannedPolarDevice(polarInfo: sdkDeviceInfo)
        connectionState = .connecting(device)
        onConnectionStateChanged?(connectionState)
    }
    
    func deviceConnected(_ sdkDeviceInfo: PolarDeviceInfo) {
        print("Polar SDK state: Connected to \(sdkDeviceInfo.name)")
        let device = ScannedPolarDevice(polarInfo: sdkDeviceInfo)
        connectionState = .connected(device)
        onConnectionStateChanged?(connectionState)
        
        // Update the main DeviceManager to prioritize the new source.
        if device.name.contains("H10") {
            DeviceManager.shared.currentSource = .polarH10
        } else {
            DeviceManager.shared.currentSource = .polar360
        }
    }
    
    func deviceDisconnected(_ sdkDeviceInfo: PolarDeviceInfo, pairingError: Bool) {
        print("Polar SDK state: Disconnected from \(sdkDeviceInfo.name)")
        connectionState = .disconnected
        onConnectionStateChanged?(connectionState)
        
        // Revert the main DeviceManager back to HealthKit as the default source.
        DeviceManager.shared.currentSource = .appleHealthKit
    }
    
    // MARK: - PolarBleApiDeviceInfoObserver (Device Information)
    
    func disInformationReceived(_ identifier: String, uuid: CBUUID, value: String) {
        print("Discovered info from \(identifier): \(uuid.uuidString) - \(value)")
    }
    
    func batteryLevelReceived(_ identifier: String, batteryLevel: UInt) {
        print("Battery level for \(identifier): \(batteryLevel)%")
    }
    
    // Other required delegate methods
    func hrFeatureReady(_ identifier: String) { print("HR feature ready for \(identifier)") }
    func hrValueReceived(_ identifier: String, data: PolarHrData) { /* Data stream handled elsewhere */ }
    func polarFtpFeatureReady(_ identifier: String) {}
}

