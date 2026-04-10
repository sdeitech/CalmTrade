//
//  PolarManager+Utilities.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/09/25.
//

import Foundation
import UIKit
import CoreBluetooth
import os.log

// MARK: - Utility, Lifecycle & Bluetooth State Handling

extension PolarManager: CBCentralManagerDelegate {

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            NSLog("[PM][BT] powered ON")
            if isShowingBluetoothAlert {
                dismissBluetoothOffAlert()
            }
            if shouldResumeSearchAfterBluetoothOn {
                startDeviceSearch()
            } else {
                resumeAutoReconnectOnForeground()
            }
        case .poweredOff:
            NSLog("[PM][BT] powered OFF")
            presentBluetoothOffAlertIfNeeded()
            _ = cancelPendingConnectIfPossible()
            stopDeviceSearch()
            connectedDevice = nil
            connectingDevice = nil
            ftuEvalPendingDeviceId = nil
            ftuEvalRetryCount = 0
            connectionState = .disconnected
        case .resetting:
            NSLog("[PM][BT] resetting")
        case .unauthorized:
            NSLog("[PM][BT] unauthorized")
        case .unsupported:
            NSLog("[PM][BT] unsupported")
        case .unknown:
            NSLog("[PM][BT] unknown state")
        @unknown default:
            NSLog("[PM][BT] unknown default state")
        }
    }

    // MARK: - Bluetooth alert

    func presentBluetoothOffAlertIfNeeded() {
        guard !isShowingBluetoothAlert else { return }

        let now = Date()
        if let last = lastBluetoothAlertAt, now.timeIntervalSince(last) < 3.0 {
            return
        }
        lastBluetoothAlertAt = now

        let alert = UIAlertController(
            title: "Bluetooth is Off",
            message: "Please enable Bluetooth to connect to your Polar device.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))

        if let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.windows.first(where: \.isKeyWindow) })
            .first,
           let vc = window.rootViewController {
            vc.present(alert, animated: true)
        } else if let root = UIApplication.shared.keyWindow?.rootViewController {
            root.present(alert, animated: true)
        }

        isShowingBluetoothAlert = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.dismissBluetoothOffAlert()
        }
    }

    func dismissBluetoothOffAlert() {
        guard isShowingBluetoothAlert else { return }
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.windows.first(where: \.isKeyWindow) })
            .first,
           let vc = window.rootViewController?.presentedViewController as? UIAlertController {
            vc.dismiss(animated: true)
        }
        isShowingBluetoothAlert = false
    }

    // MARK: - App lifecycle hooks

    func applicationDidEnterBackground(_ completion: (() -> Void)? = nil) {
        NSLog("[PM][Lifecycle] app entered background")
        pendingBgCompletion = completion
        lastBgAt = Date()

        stopDeviceSearch()
    }

    func applicationWillEnterForeground() {
        NSLog("[PM][Lifecycle] app will enter foreground")
        resumeAutoReconnectOnForeground()

        if let bgAt = lastBgAt {
            let elapsed = Date().timeIntervalSince(bgAt)
            NSLog("[PM][Lifecycle] background duration \(elapsed)s")
        }

        pendingBgCompletion?()
        pendingBgCompletion = nil
        lastBgAt = nil
    }

    // MARK: - Internal utilities

    func cancelAllTimersAndWork() {
        reconnectRetryWork?.cancel()
        reconnectRetryWork = nil
    }

    func resetInternalFlags() {
        isAutoReconnectInFlight = false
        isPpiStarting = false
        ppiStartDesired = false
        offlineStartInFlight.removeAll()
        offlineActive.removeAll()
    }

    func printDebugSummary() {
        NSLog("───────────────────────────────")
        NSLog("[PM] Summary:")
        NSLog("• Connected device: \(connectedDevice?.name ?? "none")")
        NSLog("• Battery: \(lastBatteryLevel.map { "\($0)%" } ?? "nil")")
        NSLog("• Firmware: \(lastFirmwareVersion ?? "nil")")
        NSLog("• Charging: \(String(describing: lastChargingState))")
        NSLog("• Offline active: \(offlineActive)")
        NSLog("• Stream disposables: hr=\(hrStreamDisposable != nil) ppi=\(ppiStreamDisposable != nil)")
        NSLog("───────────────────────────────")
    }

    // MARK: - Diagnostic Notifications

    func postDiagnosticNotification(_ message: String) {
        NotificationCenter.default.post(
            name: .ctPolarDiagnosticMessage,
            object: nil,
            userInfo: ["message": message]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let ctPolarDiagnosticMessage  = Notification.Name("ct.PolarDiagnosticMessage")
}
