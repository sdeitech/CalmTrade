//
//  PolarManager+Controls.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/09/25.
//  Updated by ChatGPT
//

import Foundation
import PolarBleSdk
import RxSwift
import os.log

// MARK: - Device Controls (Restart / Turn Off / Factory Reset / Time Sync / Storage)

extension PolarManager {

    // MARK: - RESTART
    func restartDevice(_ deviceId: String? = nil, preservePairing: Bool = true) {
        guard let id = deviceId ?? currentIdentifier else { return }
        NSLog("[PM][Ctrl] restartDevice(\(id))")

        api.doRestart(id, preservePairingInformation: preservePairing)
            .subscribe(
                onCompleted: { NSLog("[PM][Ctrl] restart sent → \(id)") },
                onError: { err in NSLog("[PM][Ctrl] restart error \(err)") }
            )
            .disposed(by: disposeBag)
    }

    // MARK: - TURN OFF
    func turnOff(onComplete: ((Swift.Result<Void, Error>) -> Void)? = nil) {
        guard let dev = connectedDevice else {
            NSLog("[PM][Ctrl] turnOff: no device connected")
            onComplete?(.failure(NSError(domain: "PolarManager",
                                         code: -1,
                                         userInfo: [NSLocalizedDescriptionKey: "No device connected"])))
            return
        }

        Task.detached { [weak self] in
            do {
                _ = try await self?.api.turnDeviceOff(dev.id).value
                NSLog("[PM][Ctrl] turnOff OK for %@", dev.id)
                onComplete?(.success(()))
            } catch {
                NSLog("[PM][Ctrl] turnOff error %@", error.localizedDescription)
                onComplete?(.failure(error))
            }
        }
    }

    // MARK: - FACTORY RESET
    func factoryReset(preservePairing: Bool = true, onComplete: ((Swift.Result<Void, Error>) -> Void)? = nil) {
        guard let dev = connectedDevice else {
            NSLog("[PM][Ctrl] factoryReset: no device connected")
            onComplete?(.failure(NSError(domain: "PolarManager",
                                         code: -1,
                                         userInfo: [NSLocalizedDescriptionKey: "No device connected"])))
            return
        }

        Task.detached { [weak self] in
            do {
                _ = try await self?.api.doFactoryReset(dev.id,
                                                       preservePairingInformation: preservePairing)
                    .value
                NSLog("[PM][Ctrl] factoryReset OK for %@", dev.id)
                onComplete?(.success(()))
            } catch {
                NSLog("[PM][Ctrl] factoryReset error %@", error.localizedDescription)
                onComplete?(.failure(error))
            }
        }
    }

    // MARK: - TIME SYNC (SET LOCAL TIME)
    func setLocalTimeNow(_ deviceId: String? = nil) {
        guard let id = deviceId ?? currentIdentifier else { return }

        NSLog("[PM][Ctrl] setLocalTimeNow for \(id)")
        let now = Date()

        api.setLocalTime(id, time: now, zone: .current)
            .subscribe(
                onCompleted: { NSLog("[PM][Ctrl] setLocalTime success for \(id)") },
                onError: { err in NSLog("[PM][Ctrl] setLocalTime error \(err)") }
            )
            .disposed(by: disposeBag)
    }

    // MARK: - READ DEVICE TIME (needed for timezone mismatch detection)
    func fetchDeviceTime(_ deviceId: String? = nil,
                         completion: @escaping (Swift.Result<Date, Error>) -> Void) {
        guard let id = deviceId ?? currentIdentifier else {
            completion(.failure(NSError(domain: "PolarManager",
                                        code: -22,
                                        userInfo: [NSLocalizedDescriptionKey: "No device connected"])))
            return
        }

        NSLog("[PM][Ctrl] requesting device time for \(id)")

        api.getLocalTime(id)
                    .subscribe(onSuccess: { date in
                        completion(.success(date))
                    }, onFailure: { err in
                        completion(.failure(err))
                    })
                    .disposed(by: disposeBag)
    }

    // MARK: - STORAGE STATUS (Polar 360, OH1, Verity)
    func fetchStorageStatus(_ deviceId: String? = nil,
                            completion: @escaping (Swift.Result<(used: Int, total: Int), Error>) -> Void) {

        guard let id = deviceId ?? currentIdentifier else {
            completion(.failure(NSError(domain: "PolarManager",
                                        code: -23,
                                        userInfo: [NSLocalizedDescriptionKey: "No device connected"])))
            return
        }

        NSLog("[PM][Ctrl] fetchStorageStatus for \(id)")

        api.getDiskSpace(id)
                    .subscribe(onSuccess: { disk in
                        // These fields exist in older Polar SDKs:
                        let used  = Int(disk.totalSpace - disk.freeSpace)
                        let free  = Int(disk.freeSpace)
                        let total = Int(disk.totalSpace)

                        completion(.success((used, total)))
                    }, onFailure: { err in
                        completion(.failure(err))
                    })
                    .disposed(by: disposeBag)
    }

    // MARK: - SYNC PIPELINE (already exists)
    func syncNow() {
        guard let dev = connectedDevice else {
            NSLog("[PM][Ctrl] syncNow aborted: no connected device")
            return
        }
        ensureOfflinePipeline(for: dev.id)
    }
}
