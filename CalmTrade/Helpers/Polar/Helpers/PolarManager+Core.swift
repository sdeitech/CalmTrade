//
//  PolarManager+Core.swift
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

// MARK: - Core / Discovery / Connection Logic

extension PolarManager {

    // MARK: - Discovery

    func startDeviceSearch() {
        // If BT is off, prompt immediately and bail early.
        if central.state == .poweredOff {
            presentBluetoothOffAlertIfNeeded()
            stopDeviceSearch()
            return
        }

        stopDeviceSearch()
        discoveredDevices.removeAll()
        onDevicesUpdated?([])

        searchDisposable = api.searchForDevice()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] sdkDevice in
                guard let self else { return }
                let dev = ScannedPolarDevice(polarInfo: sdkDevice)
                if !self.discoveredDevices.contains(dev) {
                    self.discoveredDevices.insert(dev)
                    self.onDeviceDiscovered?(dev)
                    self.onDevicesUpdated?(Array(self.discoveredDevices).sorted { $0.name < $1.name })
                }
            }, onError: { [weak self] (error: Error) in
                if let self, self.central.state == .poweredOff {
                    self.presentBluetoothOffAlertIfNeeded()
                }
                print("PolarManager: Device search error: \(error)")
            })
    }

    func stopDeviceSearch() {
        searchDisposable?.dispose()
        searchDisposable = nil
    }

    // MARK: - Connect / Disconnect

    func connect(to device: ScannedPolarDevice) {
        if central.state == .poweredOff {
            presentBluetoothOffAlertIfNeeded()
            return
        }

        // ✅ If already connected to this device, short-circuit to “connected”
        if let current = connectedDevice, current.id == device.id {
            connectionState = .connected(current)
            broadcastSnapshotIfCurrent()
            return
        }

        // ✅ If already *connecting* to this device, don’t start again
        if let inFlight = connectingDevice, inFlight.id == device.id {
            connectionState = .connecting(inFlight)
            return
        }

        // If connected to a different device, disconnect first then try again
        if let current = connectedDevice, current.id != device.id {
            do { try api.disconnectFromDevice(current.id) }
            catch { NSLog("disconnect error: \(error)") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.connect(to: device)
            }
            return
        }

        // If *connecting* to a different device, cancel and retry
        if let inFlight = connectingDevice, inFlight.id != device.id {
            _ = cancelPendingConnectIfPossible()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.connect(to: device)
            }
            return
        }

        // Normal fresh connect path
        stopDeviceSearch()
        connectingDevice = device
        connectionState = .connecting(device)

        do {
            try api.connectToDevice(device.id)
            waitForConnection(deviceId: device.id)
        } catch {
            if central.state == .poweredOff { presentBluetoothOffAlertIfNeeded() }
            print("PolarManager: Failed to start connection to \(device.id). Error: \(error)")
            connectingDevice = nil
            connectionState = .disconnected
        }
    }

    func disconnect() {
        guard let dev = connectedDevice else { return }
        do { try api.disconnectFromDevice(dev.id) }
        catch { print("PolarManager: Failed to disconnect from \(dev.id). Error: \(error)") }
    }

    @discardableResult
    func cancelPendingConnectIfPossible() -> Bool {
        guard let dev = connectingDevice else { return false }
        do {
            try api.disconnectFromDevice(dev.id)
            return true
        } catch {
            NSLog("cancelPendingConnectIfPossible error: \(error)")
            return false
        }
    }

    func waitForConnection(deviceId: String) {
        api.waitForConnection(deviceId)
            .observe(on: MainScheduler.instance)
            .subscribe(onCompleted: { [weak self] in
                guard let self else { return }
                if let dev = self.connectedDevice {
                    self.startBestStreaming(for: dev)
                    if self.autoOfflineSyncOnConnect {
                        self.ensureOfflinePipeline(for: dev.id)
                    }
                }
            }, onError: { err in print("waitForConnection error:", err) })
            .disposed(by: disposeBag)
    }

    // MARK: - Observers API

    @discardableResult
    func addConnectionObserver(_ block: @escaping (ConnectionState) -> Void) -> UUID {
        let id = UUID()
        connectionObservers[id] = block
        block(connectionState)
        return id
    }

    func removeConnectionObserver(_ id: UUID) {
        connectionObservers.removeValue(forKey: id)
    }

    // MARK: - Auto Reconnect

    private var lastRememberedDevice: (id: String, name: String)? {
        guard let id = defaults.string(forKey: lastDeviceIdKey),
                  let name = defaults.string(forKey: lastDeviceNameKey),
                  !id.isEmpty, !name.isEmpty else { return nil }
        return (id, name)
    }

    private func attemptAutoReconnectIfNeeded() {
        switch connectionState {
        case .connected, .connecting: return
        case .disconnected: break
        }

        guard let remembered = lastRememberedDevice else { return }
        guard !isAutoReconnectInFlight else { return }

        isAutoReconnectInFlight = true
        reconnectRetryWork?.cancel()
        reconnectRetryWork = nil

        do {
            try api.connectToDevice(remembered.id)
            waitForConnection(deviceId: remembered.id)
        } catch {
            scheduleReconnectRetry(seconds: 5)
            isAutoReconnectInFlight = false
        }
    }

    private func scheduleReconnectRetry(seconds: TimeInterval) {
        reconnectRetryWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.isAutoReconnectInFlight = false
            self?.attemptAutoReconnectIfNeeded()
        }
        reconnectRetryWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func enableAutoReconnectOnLaunch() { attemptAutoReconnectIfNeeded() }
    func resumeAutoReconnectOnForeground() {
        attemptAutoReconnectIfNeeded()
    }
}
