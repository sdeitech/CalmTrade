//
//  OfflinePPGIngestor.swift
//  CalmTrade
//
//  Ingests offline PPG data from Polar devices (per-user).
//  Stores binary PPG payloads and minimal metadata so local sleep estimation works.
//

import Foundation
import PolarBleSdk

final class OfflinePPGIngestor {
    static let shared = OfflinePPGIngestor()
    private init() {}

    struct SavedPPG: Codable {
        let deviceId: String
        let startTime: Date
        let sampleRateHz: Int
        let channels: Int
        let samplesPerChannel: Int
        let relativeTimestampsMs: [Int]
        let filePath: String
    }

    private let fm = FileManager.default

    private func baseDir(for userId: String?) -> URL {
        let id = userId ?? "_anonymous"
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Users/\(id)/OfflinePPG", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Ingest entry point
    @discardableResult
    func ingest(deviceId: String,
                start: Date,
                ppg: PolarPpgData,
                sampleRateHz: Int,
                channelsOverride: Int? = nil) -> SavedPPG? {

        let userId = SessionManager.shared.current?.id
        let (sr, ch, samplesPerCh, rel, payload) = unpack(ppg,
                                                          sampleRateHz: sampleRateHz,
                                                          channelsOverride: channelsOverride)

        let tsName = iso8601FileName(from: start)
        let dir = baseDir(for: userId)
        let file = dir.appendingPathComponent("\(deviceId)_\(tsName).ppg.raw")

        do {
            try payload.write(to: file, options: .atomic)
            NSLog("[PPG] saved %dB → %@ (sr=%dHz ch=%d samples/ch=%d)",
                  payload.count, file.lastPathComponent, sr, ch, samplesPerCh)

            let saved = SavedPPG(deviceId: deviceId,
                                 startTime: start,
                                 sampleRateHz: sr,
                                 channels: ch,
                                 samplesPerChannel: samplesPerCh,
                                 relativeTimestampsMs: rel,
                                 filePath: file.path)

            // Persist user-scoped meta
            CTMetricsRepository.shared.upsertOfflinePPGMeta(saved)

            // Broadcast event (user-aware)
            NotificationCenter.default.post(
                name: .ctOfflinePPGIngested,
                object: nil,
                userInfo: [
                    "deviceId": deviceId,
                    "start": start,
                    "filePath": file.path,
                    "userId": userId ?? "_anonymous"
                ]
            )

            return saved
        } catch {
            NSLog("[PPG] save error: %@", error.localizedDescription)
            return nil
        }
    }

    // MARK: - Helpers
    private func iso8601FileName(from d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d).replacingOccurrences(of: ":", with: "-")
    }

    private func unpack(_ ppg: PolarPpgData,
                        sampleRateHz: Int,
                        channelsOverride: Int?) -> (sr: Int, ch: Int, samples: Int, relMs: [Int], payload: Data) {
        let tuples: [(timeStamp: UInt64, channelSamples: [Int32])] = ppg.samples
        let samplesPerCh = tuples.count
        let channels = channelsOverride ?? (tuples.first?.channelSamples.count ?? 1)
        let sr = max(1, sampleRateHz)

        let relMs: [Int] = (0..<samplesPerCh).map { i in Int((Double(i) * 1000.0) / Double(sr)) }

        var payload = Data(capacity: samplesPerCh * channels * MemoryLayout<Int16>.size)
        for t in tuples {
            for v in t.channelSamples.prefix(channels) {
                var s = Int16(clamping: v)
                withUnsafeBytes(of: s.littleEndian) { payload.append(contentsOf: $0) }
            }
        }
        return (sr, channels, samplesPerCh, relMs, payload)
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let ctOfflinePPGIngested = Notification.Name("ct.offline.ppg.ingested")
}

// MARK: - Local Sleep Estimator (per-user)
enum LocalSleepEstimator {

    static func fromOfflinePPG(meta: OfflinePPGIngestor.SavedPPG) {
        guard meta.sampleRateHz > 0, meta.samplesPerChannel > 0 else {
            NSLog("[SLEEP-LOCAL] invalid meta (sr=%d, n=%d)", meta.sampleRateHz, meta.samplesPerChannel)
            return
        }

        let durSec = Double(meta.samplesPerChannel) / Double(meta.sampleRateHz)
        let start = meta.startTime
        let end = start.addingTimeInterval(durSec)
        let seg = CTSleepSegment(start: start, end: end, stage: .light, quality: "fair")
        let epi = CTSleepEpisode(date: end, source: .polar360,
                                 segments: [seg], qualityFlag: "fair")

        // Save under the current user's repository
        CTMetricsRepository.shared.upsertSleepEpisode(epi)

        NotificationCenter.default.post(
            name: .ctSleepUpdated,
            object: nil,
            userInfo: [
                "source": CTMetricSource.polar360,
                "userId": SessionManager.shared.current?.id ?? "_anonymous"
            ]
        )

        let hours = durSec / 3600.0
        NSLog("[SLEEP-LOCAL] upserted episode %.2f h, end=%@", hours, end as NSDate)
    }
}
