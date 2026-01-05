//
//  PolarManager+Offline.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/09/25.
//

import Foundation
import PolarBleSdk
import RxSwift
import os.log

// MARK: - Offline Recording & Sync

extension PolarManager {

    // MARK: - H10 Exercise Recording

    func h10StartRecording(_ deviceId: String, exerciseId: String = UUID().uuidString) {
        api.startRecording(deviceId, exerciseId: exerciseId, interval: .interval_1s, sampleType: .rr)
            .subscribe(onCompleted: { print("H10 recording started") },
                       onError: { print("H10 startRecording error:", $0) })
            .disposed(by: disposeBag)
    }

    func h10StopRecording(_ deviceId: String) {
        api.stopRecording(deviceId)
            .subscribe(onCompleted: { print("H10 recording stopped") },
                       onError: { print("H10 stopRecording error:", $0) })
            .disposed(by: disposeBag)
    }

    func h10ListAndFetchExercises(_ deviceId: String) {
        api.fetchStoredExerciseList(deviceId)
            .observe(on: MainScheduler.instance)
            .do(onNext: { [weak self] entry in
                self?.onH10ExerciseEntry?(entry)
            })
            .flatMap { [unowned self] entry in
                self.api.fetchExercise(deviceId, entry: entry).asObservable()
            }
            .subscribe(onNext: { [weak self] ex in
                self?.onH10ExerciseData?(ex)
            }, onError: { print("H10 fetch exercise error:", $0) })
            .disposed(by: disposeBag)
    }

    // MARK: - Offline (360/OH1/Verity PPG)

    func start360OfflinePpg(_ deviceId: String, attempt: Int = 0, completion: ((Bool) -> Void)? = nil) {
        if offlineActive.contains(deviceId) {
            completion?(true)
            return
        }

        api.requestOfflineRecordingSettings(deviceId, feature: .ppg)
            .flatMapCompletable { [unowned self] settings in
                NSLog("[PM] starting offline PPG with settings: \(settings)")
                return self.api.startOfflineRecording(deviceId, feature: .ppg, settings: settings, secret: nil)
            }
            .subscribe(onCompleted: { [weak self] in
                NSLog("[PM] 360 offline PPG started ✅")
                self?.offlineActive.insert(deviceId)
                completion?(true)
            }, onError: { [weak self] err in
                let msg = String(describing: err).lowercased()

                if msg.contains("already in state") {
                    NSLog("[PM] offline PPG already running — treating as started")
                    self?.offlineActive.insert(deviceId)
                    completion?(true)
                    return
                }

                if msg.contains("notificationnotenabled") && attempt < 3 {
                    let delay = 0.6 + 0.2 * Double(attempt)
                    NSLog("[PM] startOfflineRecording notificationNotEnabled; retry in \(delay)s")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self?.start360OfflinePpg(deviceId, attempt: attempt + 1, completion: completion)
                    }
                    return
                }

                print("[PM] 360 start offline PPG error:", err)
                completion?(false)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Offline Download Logic

    func listAndDownload360Offline(_ deviceId: String, attempt: Int = 0) {
        NSLog("[PM] listAndDownload360Offline begin (attempt \(attempt + 1)) for \(deviceId)")

        api.listOfflineRecordings(deviceId)
            .observe(on: MainScheduler.instance)
            .do(onNext: { [weak self] entry in
                guard let self else { return }
                self.on360OfflineEntry?(entry)
                NSLog("[PM] offline entry found: type=\(entry.type) size=\(entry.size) date=\(entry.date) path=\(entry.path)")
            })
            .flatMap { [unowned self] entry in
                self.api.getOfflineRecord(deviceId, entry: entry, secret: nil)
                    .map { (entry, $0) }
                    .asObservable()
            }
            .subscribe(onNext: { [weak self] (entry, record) in
                guard let self else { return }
                switch record {
                case .ppgOfflineRecordingData(let ppg, let startTime, let setting):
                    let sr = PolarManager.extractSampleRateHz(from: setting) ?? 22
                    let ch = PolarManager.extractChannels(from: setting) ?? 2

                    let sampleCount = ppg.samples.reduce(0) { $0 + $1.channelSamples.count }
                    NSLog("[PM] PPG offline downloaded: start=%@ setting=%@ sampleCount=%d",
                          startTime as NSDate, String(describing: setting), sampleCount)

                    _ = OfflinePPGIngestor.shared.ingest(deviceId: deviceId,
                                                         start: startTime,
                                                         ppg: ppg,
                                                         sampleRateHz: Int(sr),
                                                         channelsOverride: Int(ch))

                    onOfflinePpgIngested?(startTime, sampleCount)
                    on360OfflinePpg?(ppg, startTime)
                    clearOfflineRecord(deviceId: deviceId, entry: entry)

                default:
                    NSLog("[PM] offline record of non-PPG type: \(record)")
                }
            }, onError: { [weak self] err in
                guard let self = self else { return }
                let msg = String(describing: err).lowercased()

                if msg.contains("notificationnotenabled") && attempt < 3 {
                    let delay = 0.6 + 0.2 * Double(attempt)
                    NSLog("[PM] listOfflineRecordings notificationNotEnabled; retry in \(delay)s")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.listAndDownload360Offline(deviceId, attempt: attempt + 1)
                    }
                    return
                }

                if attempt == 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.ensureOfflinePipeline(for: deviceId)
                    }
                }

                print("[PM] getOfflineRecord/listOfflineRecordings error:", err)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Disk Management / Pipeline

    func checkAndMaintainDisk(_ deviceId: String) {
        let now = Date().timeIntervalSince1970
        let key = "ct.polar.diskcheck.last.\(deviceId)"
        let last = defaults.double(forKey: key)
        if now - last < 3600 { return }
        defaults.set(now, forKey: key)

        api.getDiskSpace(deviceId)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] ds in
                guard let self else { return }

                guard let (used, total) = PolarManager.unpackDiskSpace(ds) else {
                    NSLog("[PM] getDiskSpace: could not extract fields for \(deviceId)")
                    return
                }

                let pct = Double(used) / max(1.0, Double(total))
                NSLog("[PM] disk space used=\(used)/\(total) (\(Int(pct * 100))%) for \(deviceId)")

                if pct >= 0.80 {
                    self.listAndDownload360Offline(deviceId)
                }
            }, onFailure: { err in
                print("getDiskSpace error:", err)
            })
            .disposed(by: disposeBag)
    }

    func clearOfflineRecord(deviceId: String, entry: PolarOfflineRecordingEntry) {
        api.removeOfflineRecord(deviceId, entry: entry)
            .subscribe(onCompleted: {
                NSLog("[PM] cleared offline entry \(entry) for \(deviceId)")
            }, onError: { err in
                print("removeOfflineRecord error:", err)
            })
            .disposed(by: disposeBag)
    }

    func verifyOfflineRecordingHealth(_ deviceId: String) {
        let ready = api.isFeatureReady(deviceId, feature: .feature_polar_offline_recording)
        NSLog("[PM] offline feature ready: \(ready) for \(deviceId)")

        api.listOfflineRecordings(deviceId)
            .toArray()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { entries in
                NSLog("[PM] offline entries count=\(entries.count) for \(deviceId)")
                for e in entries { NSLog("[PM] entry: \(e)") }
            }, onFailure: { err in
                print("[PM] listOfflineRecordings error:", err)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Ordered Offline Pipeline

    internal func ensureOfflinePipeline(for deviceId: String) {
        if offlineStartInFlight.contains(deviceId) { return }
        offlineStartInFlight.insert(deviceId)

        start360OfflinePpg(deviceId) { [weak self] started in
            guard let self else { return }
            self.offlineStartInFlight.remove(deviceId)
            if started { self.offlineActive.insert(deviceId) }

            self.checkAndMaintainDisk(deviceId)
            self.listAndDownload360Offline(deviceId)
            self.triggerPolar360DailySync(deviceId)
            self.verifyOfflineRecordingHealth(deviceId)
        }
    }
    
    func triggerPolar360DailySync(_ deviceId: String) {
        NotificationCenter.default.post(name: .ctRequestPolarDailySync, object: nil, userInfo: ["deviceId": deviceId])
    }
}

extension PolarManager {
    func appDidEnterBackground(onStabilized: @escaping () -> Void) {
        // Don’t stop streams here. Just mark and run a quick health check on a background-safe queue.
        pendingBgCompletion = onStabilized
        lastBgAt = Date()
        
        // If you accidentally background without BLE mode, warn once (dev-only)
#if DEBUG
        if !Self._hasBluetoothCentralBackgroundMode() {
            NSLog("[PM] ⚠️ UIBackgroundModes bluetooth-central is NOT enabled. Background streaming will suspend.")
        }
#endif
        
        // Minimal work: confirm we still have active disposables or re-arm intent flags.
        // No heavy networking here; let the OS coalesce.
        if case .connected(let dev) = connectionState {
            // make sure our desired streams are still desired/armed
            if ppiStartDesired && ppiStreamDisposable == nil && !isPpiStarting {
                // don’t actually start here; just leave desire true. The FG hook will re-verify.
            }
            // HR stream should already be active; do nothing unless it failed below.
        }
        
        // hand control back quickly; the OS may give ~10–30s background time total
        pendingBgCompletion?()
        pendingBgCompletion = nil
    }
    
    /// Called from AppDelegate.applicationWillEnterForeground
    func appWillEnterForeground() {
        // Light sanity checks. Avoid duplicate starts.
        guard case .connected(let dev) = connectionState else { return }
        
        // If HR/RR were disposed by the system, re-try them.
        if hrStreamDisposable == nil {
            startHrStreaming(for: dev)
        }
        if ppiStartDesired && ppiStreamDisposable == nil && !isPpiStarting {
            startPpiStreaming(for: dev)
        }
        
        if let dev = connectedDevice {
            PolarDailySyncCoordinator.shared.fetchTodayAndYesterday(deviceId: dev.id)
        }
        
        // Opportunistically refresh snapshot (battery/firmware) for UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.broadcastSnapshotIfCurrent()
        }
    }
    
    private static func _hasBluetoothCentralBackgroundMode() -> Bool {
        guard let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] else { return false }
        return modes.contains("bluetooth-central")
    }
}
