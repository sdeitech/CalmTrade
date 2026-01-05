//
//  PolarManager+BatteryInfo.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/09/25.
//

import Foundation
import PolarBleSdk
import CoreBluetooth
import os.log

// MARK: - Device Info & Battery Handling

extension PolarManager {

    func disInformationReceived(_ identifier: String, uuid: CBUUID, value: String) {
        // optional diagnostic only
    }

    func disInformationReceivedWithKeysAsStrings(_ identifier: String, key: String, value: String) {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        NSLog("[PM] DIS key='\(k)' value='\(v)' from \(identifier)")

        let isFirmwareishUuid = (k == "2a26") || (k == "2a28")
        let isFirmwareishName = k.contains("firmware") || k.contains("software")
            || k.contains("revision") || k.contains("version")

        if isFirmwareishUuid || isFirmwareishName {
            lastFirmwareVersion = v
            NSLog("[PM] captured firmware/software string='\(v)'")
            broadcastSnapshotIfCurrent()
            return
        }
    }

    func batteryLevelReceived(_ identifier: String, batteryLevel: UInt) {
        lastBatteryLevel = batteryLevel
        NSLog("[PM] battery level \(batteryLevel)% for \(identifier)")
        onBatteryUpdate?(identifier, batteryLevel, nil)
        broadcastSnapshotIfCurrent()
    }

    func batteryChargingStatusReceived(_ identifier: String, chargingStatus: BleBasClient.ChargeState) {
        lastChargingState = chargingStatus
        NSLog("[PM] charging state \(chargingStatus) for \(identifier)")
        onBatteryUpdate?(identifier, lastBatteryLevel ?? 0, chargingStatus == .charging)
        broadcastSnapshotIfCurrent()
    }
}

// MARK: - Snapshot Broadcasts

extension PolarManager {

    func refreshSnapshot() {
        broadcastSnapshotIfCurrent()
    }

    internal func broadcastSnapshotIfCurrent() {
        guard case .connected(let dev) = connectionState else {
            NSLog("[PM] broadcastSnapshotIfCurrent skipped (not connected)")
            return
        }

        let snap = PolarDeviceSnapshot(
            id: dev.id,
            name: dev.name,
            firmware: lastFirmwareVersion,
            batteryLevel: lastBatteryLevel,
            charging: (lastChargingState == .charging),
            timestamp: Date()
        )

        NSLog("[PM] broadcasting snapshot id=\(snap.id) name=\(snap.name) fw=\(snap.firmware ?? "nil") batt=\(snap.batteryLevel?.description ?? "nil") charging=\(String(describing: snap.charging))")

        onSnapshot?(snap)
        NotificationCenter.default.post(
            name: .ctDeviceSnapshotDidChange,
            object: nil,
            userInfo: [
                "id": snap.id,
                "name": snap.name,
                "firmware": snap.firmware as Any,
                "battery": snap.batteryLevel as Any,
                "charging": snap.charging as Any,
                "timestamp": snap.timestamp
            ]
        )
    }
}
