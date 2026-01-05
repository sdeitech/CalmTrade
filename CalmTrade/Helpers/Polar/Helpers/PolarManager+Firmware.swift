//
//  PolarManager+Firmware.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/09/25.
//

import Foundation
import PolarBleSdk
import RxSwift
import os.log

// MARK: - Firmware Update Logic

extension PolarManager {

    func checkAndUpdateFirmwareIfNeeded(
        autoUpdate: Bool = true,
        minBatteryPercent: UInt? = nil,
        firmwareURL: URL? = nil
    ) {
        guard case .connected(let dev) = connectionState else { return }

        guard supportsSdkFirmwareUpdate(dev) else {
            onFwCheck?(.checkFwUpdateFailed(details: "Not supported on this device"))
            return
        }

        if let min = minBatteryPercent, let lvl = lastBatteryLevel, lvl < min {
            let msg = "Battery \(lvl)% below threshold \(min)% — skipping FWU check."
            onFwCheck?(.checkFwUpdateFailed(details: msg))
            return
        }

        fwDisposable?.dispose()
        fwDisposable = api.checkFirmwareUpdate(dev.id)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                guard let self = self else { return }
                self.onFwCheck?(status)
                switch status {
                case .checkFwUpdateAvailable:
                    if autoUpdate {
                        self.startFirmwareUpdate(identifier: dev.id, firmwareURL: firmwareURL)
                    }
                case .checkFwUpdateNotAvailable, .checkFwUpdateFailed:
                    break
                }
            }, onError: { [weak self] err in
                self?.onFwError?(err)
            })
    }

    func checkFirmwareUpdateNonForced(minBatteryPercent: UInt = 30) {
        guard !isFwUpdatingInternal else {
            os_log("[FW] checkFirmwareUpdateNonForced ignored: update in progress", log: fwLog, type: .info)
            return
        }

        guard case .connected(let dev) = connectionState else {
            onFwCheck?(.checkFwUpdateFailed(details: "No connected device"))
            NotificationCenter.default.post(
                name: .ctFwCheck,
                object: nil,
                userInfo: ["status": CheckFirmwareUpdateStatus.checkFwUpdateFailed(details: "No connected device")]
            )
            return
        }

        guard supportsSdkFirmwareUpdate(dev) else {
            let s: CheckFirmwareUpdateStatus = .checkFwUpdateFailed(details: "Not supported on this device")
            onFwCheck?(s)
            NotificationCenter.default.post(name: .ctFwCheck, object: nil, userInfo: ["status": s])
            return
        }

        if let lvl = lastBatteryLevel, lvl < minBatteryPercent {
            let msg = "Battery \(lvl)% below threshold \(minBatteryPercent)% — skipping FWU check."
            let s: CheckFirmwareUpdateStatus = .checkFwUpdateFailed(details: msg)
            onFwCheck?(s)
            NotificationCenter.default.post(name: .ctFwCheck, object: nil, userInfo: ["status": s])
            return
        }

        fwDisposable?.dispose()
        fwDisposable = api.checkFirmwareUpdate(dev.id)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                guard let self else { return }
                self.onFwCheck?(status)
                NotificationCenter.default.post(name: .ctFwCheck, object: nil, userInfo: ["status": status])
            }, onError: { [weak self] err in
                self?.onFwError?(err)
                NotificationCenter.default.post(name: .ctFwCheck, object: nil, userInfo: [
                    "status": CheckFirmwareUpdateStatus.checkFwUpdateFailed(details: err.localizedDescription)
                ])
            })
    }

    func beginFirmwareUpdate() {
        guard case .connected(let dev) = connectionState else {
            NotificationCenter.default.post(name: .ctFwProgress, object: nil,
                                            userInfo: ["progress": FirmwareProgress(stage: "Error", detail: "No connected device", fraction: nil)])
            return
        }
        startFirmwareUpdate(identifier: dev.id, firmwareURL: nil)
    }

    private func startFirmwareUpdate(identifier: String, firmwareURL: URL? = nil) {
        let attemptId = UUID().uuidString.prefix(8)

        os_log("[FW %@] ▶️ startFirmwareUpdate(id=%{public}@, url?=%{public}@)",
               log: fwLog, type: .info, String(attemptId), identifier, firmwareURL?.absoluteString ?? "nil")

        fwDisposable?.dispose()
        os_log("[FW %@] disposed previous fwDisposable (if any)", log: fwLog, type: .debug, String(attemptId))

        let src: Observable<FirmwareUpdateStatus> = (firmwareURL != nil)
            ? api.updateFirmware(identifier, fromFirmwareURL: firmwareURL!)
            : api.updateFirmware(identifier)

        let stream = src
            .materialize()
            .share(replay: 0)

        fwDisposable = stream
            .do(onSubscribe: { [weak self] in
                os_log("[FW %@] subscription started", log: self!.fwLog, type: .info, String(attemptId))
                NotificationCenter.default.post(name: .ctFwProgress, object: nil,
                    userInfo: ["progress": FirmwareProgress(stage: "Starting", detail: "Preparing update…", fraction: 0.0),
                               "attemptId": String(attemptId)])
            }, onDispose: {
                os_log("[FW %@] subscription disposed", log: self.fwLog, type: .debug, String(attemptId))
            })
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                guard let self else { return }
                switch event {
                case .next(let stamped):
                    let status = stamped
                    let p = self.normalize(status: status)
                    os_log("[FW %@] onNext %@ → stage=%{public}@ detail=%{public}@ fraction=%{public}@",
                           log: fwLog, type: .info, String(attemptId),
                           String(describing: status),
                           p.stage, p.detail ?? "nil",
                           p.fraction != nil ? String(format: "%.3f", p.fraction!) : "nil")

                    self.onFwStatus?(status)
                    self.broadcastSnapshotIfCurrent()

                    NotificationCenter.default.post(name: .ctFwProgress, object: nil,
                        userInfo: ["progress": p, "attemptId": String(attemptId)])

                    self.isFwUpdatingInternal = false

                case .error(let err):
                    os_log("[FW %@] ❌ error: %{public}@", log: fwLog, type: .error, String(attemptId), err.localizedDescription)
                    self.onFwError?(err)
                    NotificationCenter.default.post(name: .ctFwProgress, object: nil,
                        userInfo: ["error": err, "attemptId": String(attemptId)])
                    self.isFwUpdatingInternal = false

                case .completed:
                    os_log("[FW %@] ✅ completed", log: fwLog, type: .info, String(attemptId))
                    NotificationCenter.default.post(name: .ctFwProgress, object: nil,
                        userInfo: ["progress": FirmwareProgress(stage: "Completed", detail: nil, fraction: 1.0),
                                   "attemptId": String(attemptId)])
                    self.isFwUpdatingInternal = false
                }
            })
    }

    private func supportsSdkFirmwareUpdate(_ device: ScannedPolarDevice) -> Bool {
        api.isFeatureReady(device.id, feature: .feature_polar_firmware_update)
    }

    private func normalize(status: FirmwareUpdateStatus) -> FirmwareProgress {
        switch status {
        case .fetchingFwUpdatePackage(let d): return .init(stage: "Fetching", detail: d, fraction: 0.10)
        case .preparingDeviceForFwUpdate(let d): return .init(stage: "Preparing device", detail: d, fraction: 0.45)
        case .writingFwUpdatePackage(let d): return .init(stage: "Writing", detail: d, fraction: 0.75)
        case .finalizingFwUpdate(let d): return .init(stage: "Finalizing", detail: d, fraction: 0.97)
        case .fwUpdateCompletedSuccessfully(let d): return .init(stage: "Completed", detail: d.isEmpty ? nil : d, fraction: 1.0)
        case .fwUpdateNotAvailable(let d): return .init(stage: "Not available", detail: d.isEmpty ? "Your device is up to date." : d, fraction: nil)
        case .fwUpdateFailed(let d): return .init(stage: "Error", detail: d.isEmpty ? "Unknown error" : d, fraction: nil)
        }
    }

    private func percentFrom(details: String) -> Double? {
        if let m = details.range(of: #"(\d{1,3})\s*%"#, options: .regularExpression) {
            let pctString = String(details[m]).replacingOccurrences(of: "%", with: "")
            if let pct = Double(pctString), pct >= 0, pct <= 100 { return pct / 100.0 }
        }
        if let m = details.range(of: #"(\d+)\s*/\s*(\d+)"#, options: .regularExpression) {
            let pair = String(details[m]).split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
            if pair.count == 2, let x = Double(pair[0]), let y = Double(pair[1]), y > 0 { return min(1.0, x / y) }
        }
        if let m = details.range(of: #"(\d+)\s+of\s+(\d+)"#, options: .regularExpression) {
            let nums = String(details[m]).components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Double.init)
            if nums.count >= 2, nums[1] > 0 { return min(1.0, nums[0] / nums[1]) }
        }
        return nil
    }

    private func map(_ f: Double?, into minV: Double, _ maxV: Double) -> Double? {
        guard let f else { return nil }
        let clamped = max(0.0, min(1.0, f))
        return minV + (maxV - minV) * clamped
    }
}
