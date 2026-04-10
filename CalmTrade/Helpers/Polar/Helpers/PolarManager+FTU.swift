//
//  PolarManager+FTU.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/09/25.
//

import Foundation
import PolarBleSdk
import os.log

// MARK: - First Time Use (FTU) Handling

extension PolarManager {

    private func ftuCompletionKey(for deviceId: String) -> String {
        "\(firstUseKeyPrefix)\(deviceId)"
    }

    private func isFtuMarkedComplete(for deviceId: String) -> Bool {
        defaults.bool(forKey: ftuCompletionKey(for: deviceId))
    }

    private func markFtuComplete(for deviceId: String, completed: Bool) {
        defaults.set(completed, forKey: ftuCompletionKey(for: deviceId))
    }

    // MARK: - FTU Evaluation Helpers

    func armFtuEvaluation(for dev: ScannedPolarDevice) {
        ftuEvalPendingDeviceId = dev.id
        ftuEvalRetryCount = 0
        maybeEvaluateFTU(reason: "initial-after-connect")
        scheduleFtuRetry()
    }

    private func scheduleFtuRetry() {
        guard let id = ftuEvalPendingDeviceId, ftuEvalRetryCount < ftuEvalRetryMax else { return }
        let delay = 0.35 + Double(ftuEvalRetryCount) * 0.25
        ftuEvalRetryCount += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.ftuEvalPendingDeviceId == id else { return }
            self.maybeEvaluateFTU(reason: "retry-\(self.ftuEvalRetryCount)")
            self.scheduleFtuRetry()
        }
    }

    func probeFtuStatus(reason: String, attempt: Int = 0) {
        guard case .connected(let dev) = connectionState else { return }
        if isFtuMarkedComplete(for: dev.id) { return }
        guard api.isFeatureReady(dev.id, feature: .feature_polar_features_configuration_service) else {
            NSLog("[PM][FTU] probe(\(reason)) skipped; CFG feature not ready")
            return
        }
        NSLog("[PM][FTU] probe(\(reason)) attempt=\(attempt+1)")

        Task {
            do {
                let done = try await api.isFtuDone(dev.id).value
                NSLog("[PM][FTU] isFtuDone -> \(done)")
                self.markFtuComplete(for: dev.id, completed: done)
                if done {
                    self.ftuEvalPendingDeviceId = nil
                    return
                }
                self.ftuEvalPendingDeviceId = nil
                self.onFirstTimeUseNeeded?(dev)
            } catch let gatt as BleGattException {
                NSLog("[PM][FTU] isFtuDone gatt error: \(gatt)")
                // Transient on reconnect. Do not prompt FTU on uncertain state.
            } catch {
                NSLog("[PM][FTU] isFtuDone error: \(error)")
                // Transient/unknown. Wait for a later successful probe.
            }
        }
    }

    func maybeEvaluateFTU(reason: String) {
        guard let dev = connectedDevice else { return }
        if isFtuMarkedComplete(for: dev.id) { return }
        let n = dev.name.lowercased()
        let looksLikeWrist = n.contains("360") || n.contains("verity") || n.contains("oh1")
            || n.contains("ignite") || n.contains("pacer") || n.contains("unite")
            || n.contains("vantage") || n.contains("grit")
        guard looksLikeWrist else { return }
        guard api.isFeatureReady(dev.id, feature: .feature_polar_features_configuration_service) else {
            NSLog("[PM][FTU] maybeEvaluateFTU(\(reason)) skipped; CFG feature not ready")
            return
        }

        NSLog("[PM][FTU] maybeEvaluateFTU(\(reason)) – probing isFtuDone()")
        Task {
            do {
                let done = try await api.isFtuDone(dev.id).value
                NSLog("[PM][FTU] isFtuDone -> \(done)")
                self.markFtuComplete(for: dev.id, completed: done)
                if done {
                    self.ftuEvalPendingDeviceId = nil
                    return
                }
                self.ftuEvalPendingDeviceId = nil
                self.onFirstTimeUseNeeded?(dev)
            } catch {
                NSLog("[PM][FTU] isFtuDone error: \(error)")
                // Do not show FTU UI on probe failure; retry loop/feature-ready callback will probe again.
            }
        }
    }

    // MARK: - External FTU Evaluator	

    func evaluateFirstTimeUseIfNeeded(for dev: ScannedPolarDevice) {
        Task {
            guard let id = currentIdentifier else { return }
            if self.isFtuMarkedComplete(for: id) { return }

            let cfgReady = api.isFeatureReady(id, feature: .feature_polar_features_configuration_service)
            NSLog("[PM][FTU] feature CFG ready on %@ : %@", id, cfgReady.description)
            guard cfgReady else { return }

            let n = dev.name.lowercased()
            let looksLikeWrist = n.contains("360") || n.contains("verity") || n.contains("oh1")
                || n.contains("ignite") || n.contains("pacer") || n.contains("unite")
                || n.contains("vantage") || n.contains("grit")
            NSLog("[PM][FTU] wrist-like=%@ for name='%@'", looksLikeWrist.description, dev.name)
            guard looksLikeWrist else { return }

            do {
                let done = try await api.isFtuDone(id).value
                NSLog("[PM][FTU] isFtuDone(%@) -> %@", id, done.description)
                self.markFtuComplete(for: id, completed: done)
                if done {
                    self.ftuEvalPendingDeviceId = nil
                    return
                }
                self.ftuEvalPendingDeviceId = nil
                self.onFirstTimeUseNeeded?(dev)
            } catch {
                NSLog("[PM][FTU] isFtuDone error: %@", String(describing: error))
                // Keep state unchanged on errors; avoid false FTU prompts.
            }
        }
    }

    func isFtuCompleteForCurrentDevice() async -> Bool {
        guard let id = currentIdentifier else { return false }
        if isFtuMarkedComplete(for: id) { return true }

        do {
            let done = try await api.isFtuDone(id).value
            markFtuComplete(for: id, completed: done)
            return done
        } catch {
            return false
        }
    }

    // MARK: - Execute First Time Use Setup

    func performFirstTimeUse(config: PolarFirstTimeUseConfig, restartAfter: Bool = false) {
        Task {
            guard let id = currentIdentifier else { return }
            do {
                await MainActor.run { self.onFtuProgress?("Sending setup…") }
                _ = try await api.doFirstTimeUse(id, ftuConfig: config).value

                await MainActor.run { self.onFtuProgress?("Verifying setup…") }
                let done = try await api.isFtuDone(id).value
                guard done else {
                    throw NSError(
                        domain: "PolarFTU",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "First-time setup did not complete on device."]
                    )
                }

                markFtuComplete(for: id, completed: true)

                await MainActor.run { self.onFtuProgress?("Syncing time…") }
                _ = try await api.setLocalTime(id, time: Date(), zone: .current).value
                if restartAfter {
                    await MainActor.run { self.onFtuProgress?("Restarting…") }
                    do { _ = try await api.doRestart(id, preservePairingInformation: true).value }
                    catch BleGattException.gattDisconnected {
                        // ignore disconnect during restart
                    }
                }
                await MainActor.run { self.onFtuCompleted?() }
            } catch {
                await MainActor.run { self.onFtuError?(error) }
            }
        }
    }
}
