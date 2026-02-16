//
//  PolarManager+Streaming.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/09/25.
//

import Foundation
import PolarBleSdk
import RxSwift
import os.log

// MARK: - Streaming (HR / PPI / ECG / PPG)

extension PolarManager {

    // MARK: - Start Best Streaming

    internal func startBestStreaming(for device: ScannedPolarDevice) {
        stopAllStreaming()
        
        // Always try HR (from HR characteristic only)
        startHrStreamingIfPossible(for: device)
        
        let name = device.name.lowercased()
        let isOptical = name.contains("360") || name.contains("verity") || name.contains("oh1")
        
        if isOptical {
            // We want PPI, but only once the feature is ready
            ppiStartDesired = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                self.maybeStartPpiWhenReady(for: device)
            }
            return
        }
        
        // Straps: only run PPI if the device actually exposes it
        api.getAvailableOnlineStreamDataTypes(device.id)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] types in
                guard let self else { return }
                if types.contains(.ppi) {
                    self.ppiStartDesired = true
                    self.maybeStartPpiWhenReady(for: device)
                } else {
                    self.ppiStartDesired = false
                }
            }, onFailure: { [weak self] _ in
                self?.ppiStartDesired = false
            })
            .disposed(by: disposeBag)
    }

    func startHrStreamingIfPossible(for device: ScannedPolarDevice) {
        let name = device.name.lowercased()
        let isStrap = name.contains("h10") || name.contains("h9")
        
        if isStrap && !isHrReady {
#if DEBUG
            print("HR not ready yet; waiting for hrFeatureReady()")
#endif
            return
        }
        
        if hrStreamDisposable != nil { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.startHrStreaming(for: device)
        }
    }

    // MARK: - HR Streaming (H9 / H10)

    func startHrStreaming(for device: ScannedPolarDevice) {
        stopHrStreaming()
        
        hrStreamDisposable = api.startHrStreaming(device.id)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] samples in
                guard let self = self else { return }
                let ts = Date()
                
                if let last = samples.last {
                    self.onHeartRate?(Double(last.hr), ts)
                }
                
                let allRRs = samples
                    .filter { $0.rrAvailable && !$0.rrsMs.isEmpty }
                    .flatMap { $0.rrsMs.map { Int($0) } }
                if !allRRs.isEmpty {
                    self.onRRIntervals?(allRRs, ts)
                }
                
            }, onError: { [weak self] error in
                guard let self = self else { return }
                print("HR stream error: \(error)")
                
                let msg = String(describing: error).lowercased()
                if msg.contains("notificationnotenabled") || msg.contains("notification not enabled") {
                    if self.hrStartRetry < 2 {
                        self.hrStartRetry += 1
                        self.stopHrStreaming()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            if let dev = self.connectedDevice {
                                self.startHrStreamingIfPossible(for: dev)
                            }
                        }
                        return
                    }
                }
                
                self.stopHrStreaming()
            })
    }
    
    // MARK: - PPI Streaming (Optical: 360 / Verity / OH1)

    func startPpiStreaming(for device: ScannedPolarDevice, attempt: Int = 0) {
        if isPpiStarting { return }
        if ppiStreamDisposable != nil { return }

        isPpiStarting = true
        ppiStartRetry = attempt

        #if DEBUG
        print("📡 startPpiStreaming attempt \(attempt + 1) on \(device.name)")
        #endif

        ppiStreamDisposable = api.startPpiStreaming(device.id)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] ppiData in
                guard let self = self else { return }
                self.isPpiStarting = false
                let ts = Date()

                #if DEBUG
                print("📡 PPI subscribed on \(device.name)")
                #endif

                let rr = ppiData.samples.map { Int($0.ppInMs) }
                if !rr.isEmpty { self.onRRIntervals?(rr, ts) }

                #if DEBUG
                print("PPI batch rrCount=\(rr.count) ts=\(ts)")
                #endif
            }, onError: { [weak self] error in
                guard let self = self else { return }
                self.isPpiStarting = false
                self.ppiStreamDisposable?.dispose()
                self.ppiStreamDisposable = nil

                let msg = String(describing: error).lowercased()
                if (msg.contains("notificationnotenabled") || msg.contains("notification not enabled")) && self.ppiStartRetry < 3 {
                    let delay = 0.6 + 0.2 * Double(self.ppiStartRetry)
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.startPpiStreaming(for: device, attempt: self.ppiStartRetry + 1)
                    }
                    return
                }

                if msg.contains("already in state") && self.ppiStartRetry < 1 {
                    self.stopAllStreaming()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.startPpiStreaming(for: device, attempt: self.ppiStartRetry + 1)
                    }
                    return
                }

                print("❌ PPI stream error (giving up): \(error)")
            })
    }

    func maybeStartPpiWhenReady(for device: ScannedPolarDevice, retry: Int = 0) {
        guard ppiStartDesired else { return }
        if ppiStreamDisposable != nil || isPpiStarting { return }

        let ready = api.isFeatureReady(device.id, feature: .feature_polar_online_streaming)
        if !ready {
            if retry < 5 {
                let delay = 0.35 + 0.15 * Double(retry)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.maybeStartPpiWhenReady(for: device, retry: retry + 1)
                }
            } else {
                #if DEBUG
                print("PPI not ready after retries; giving up for now")
                #endif
            }
            return
        }
        startPpiStreaming(for: device)
    }

    // MARK: - ECG Streaming

    func startEcgStreaming(_ deviceId: String, onData: @escaping (PolarEcgData) -> Void) {
        ecgStreamDisposable?.dispose()
        api.requestStreamSettings(deviceId, feature: .ecg)
            .asObservable()
            .flatMap { [unowned self] settings -> Observable<PolarEcgData> in
                self.api.startEcgStreaming(deviceId, settings: settings)
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { onData($0) },
                       onError: { print("ECG error:", $0) })
            .disposed(by: disposeBag)
    }

    // MARK: - Live PPG Streaming

    func startLivePpgStreaming(_ deviceId: String, onData: @escaping (PolarPpgData) -> Void) {
        ppgStreamDisposable?.dispose()
        api.requestStreamSettings(deviceId, feature: .ppg)
            .asObservable()
            .flatMap { [unowned self] settings -> Observable<PolarPpgData> in
                self.api.startPpgStreaming(deviceId, settings: settings)
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { onData($0) },
                       onError: { print("PPG error:", $0) })
            .disposed(by: disposeBag)
    }

    // MARK: - Stop Streaming

    internal func stopAllStreaming() {
        hrStreamDisposable?.dispose();  hrStreamDisposable  = nil
        ppiStreamDisposable?.dispose(); ppiStreamDisposable = nil
        ecgStreamDisposable?.dispose(); ecgStreamDisposable = nil
        ppgStreamDisposable?.dispose(); ppgStreamDisposable = nil
        isPpiStarting = false
    }

    internal func stopHrStreaming() {
        hrStreamDisposable?.dispose()
        hrStreamDisposable = nil
    }
}
