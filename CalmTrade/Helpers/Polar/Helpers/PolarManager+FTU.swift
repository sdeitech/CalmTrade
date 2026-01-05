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

    // MARK: - FTU Evaluation Helpers

    private func armFtuEvaluation(for dev: ScannedPolarDevice) {
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
        NSLog("[PM][FTU] probe(\(reason)) attempt=\(attempt+1)")

        Task {
            do {
                let done = try await api.isFtuDone(dev.id).value
                NSLog("[PM][FTU] isFtuDone -> \(done)")
                if !done { self.onFirstTimeUseNeeded?(dev) }
            } catch let gatt as BleGattException {
                NSLog("[PM][FTU] isFtuDone gatt error: \(gatt)")
                self.onFirstTimeUseNeeded?(dev)
            } catch {
                NSLog("[PM][FTU] isFtuDone error: \(error)")
                self.onFirstTimeUseNeeded?(dev)
            }
        }
    }

    func maybeEvaluateFTU(reason: String) {
        guard let dev = connectedDevice else { return }
        let n = dev.name.lowercased()
        let looksLikeWrist = n.contains("360") || n.contains("verity") || n.contains("oh1")
            || n.contains("ignite") || n.contains("pacer") || n.contains("unite")
            || n.contains("vantage") || n.contains("grit")
        guard looksLikeWrist else { return }

        NSLog("[PM][FTU] maybeEvaluateFTU(\(reason)) – probing isFtuDone()")
        Task {
            do {
                let done = try await api.isFtuDone(dev.id).value
                NSLog("[PM][FTU] isFtuDone -> \(done)")
                if !done { self.onFirstTimeUseNeeded?(dev) }
            } catch {
                NSLog("[PM][FTU] isFtuDone error: \(error)")
                self.onFirstTimeUseNeeded?(dev)
            }
        }
    }

    // MARK: - External FTU Evaluator

    func evaluateFirstTimeUseIfNeeded(for dev: ScannedPolarDevice) {
        Task {
            guard let id = currentIdentifier else { return }

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
                if !done { self.onFirstTimeUseNeeded?(dev) }
            } catch {
                NSLog("[PM][FTU] isFtuDone error: %@", String(describing: error))
                self.onFirstTimeUseNeeded?(dev)
            }
        }
    }

    // MARK: - Execute First Time Use Setup

    func performFirstTimeUse(config: PolarFirstTimeUseConfig, restartAfter: Bool = false) {
        Task {
            guard let id = currentIdentifier else { return }
            await MainActor.run { self.onFtuProgress?("Sending setup…") }
            _ = try await api.doFirstTimeUse(id, ftuConfig: config).value
            await MainActor.run { self.onFtuProgress?("Syncing time…") }
            _ = try await api.setLocalTime(id, time: Date(), zone: .current).value
            if restartAfter {
                await MainActor.run { self.onFtuProgress?("Restarting…") }
                do { _ = try await api.doRestart(id, preservePairingInformation: true).value }
                catch let gatt as BleGattException where gatt == .gattDisconnected { }
            }
            await MainActor.run { self.onFtuCompleted?() }
        }
    }
}
