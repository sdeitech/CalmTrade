//
//  Polar360SyncService.swift
//  CalmTrade
//
//  Created by Anas Parekh on 15/10/25.
//

import Foundation
import PolarBleSdk

// MARK: - Fetcher protocol (inject your real implementation)
protocol Polar360SleepFetching {
    /// Fetch last-night sleep packet for a given device.
    func fetchLastNightSleep(
        deviceId: String,
        completion: @escaping (Swift.Result<P360SleepPacket, Error>) -> Void
    )
}

// MARK: - Safe default (no-op) fetcher so this file compiles without your cloud client
final class Polar360NoopFetcher: Polar360SleepFetching {
    private struct NotConfiguredError: LocalizedError {
        var errorDescription: String? {
            "Polar360SleepFetching is not configured. Provide a real fetcher to Polar360SyncService."
        }
    }

    func fetchLastNightSleep(
        deviceId: String,
        completion: @escaping (Swift.Result<P360SleepPacket, Error>) -> Void
    ) {
        completion(.failure(NotConfiguredError()))
    }
}

// MARK: - Optional adapter template for your real cloud client
// Implement this in your project if you have a Polar cloud/SDK client.
// Then pass an instance into Polar360SyncService(fetcher: ...)

final class PolarCloudFetcher: Polar360SleepFetching {

    private let baseURL: URL
    init(baseURL: URL = PolarCloudAPI.defaultBaseURL) {
        self.baseURL = baseURL
    }

    func fetchLastNightSleep(
        deviceId: String,
        completion: @escaping (Swift.Result<P360SleepPacket, Error>) -> Void
    ) {
        PolarCloudAPI.fetchLastNightSleep(baseURL: baseURL, deviceId: deviceId, completion: completion)
    }
}

// MARK: - Service

final class Polar360SyncService {

    // Keep a strong ref somewhere long-lived (AppDelegate/SceneDelegate/singleton)
    init(fetcher: Polar360SleepFetching = Polar360NoopFetcher()) {
        self.fetcher = fetcher
        self.token = NotificationCenter.default.addObserver(
            forName: .ctRequestPolarDailySync,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard let deviceId = note.userInfo?["deviceId"] as? String else {
                NSLog("[SYNC] ctRequestPolarDailySync received without deviceId")
                return
            }
            self.fetchAndSubmitSleep(for: deviceId)
        }

        NSLog("[SYNC] Polar360SyncService ready (observer installed)")
    }

    deinit {
        if let t = token { NotificationCenter.default.removeObserver(t) }
        NSLog("[SYNC] Polar360SyncService deinit (observer removed)")
    }

    /// Manually trigger a fetch (e.g., from a debug button).
    func triggerNow(for deviceId: String) {
        fetchAndSubmitSleep(for: deviceId)
    }

    // MARK: Private

    private let fetcher: Polar360SleepFetching
    private var token: NSObjectProtocol?
    private let manager = PolarManager.shared

    private func fetchAndSubmitSleep(for deviceId: String) {
        NSLog("[SYNC] fetching Polar 360 sleep for device=\(deviceId) …")

        fetcher.fetchLastNightSleep(deviceId: deviceId) { [weak self] (result: Swift.Result<P360SleepPacket, Error>) in
            guard let self else { return }
            switch result {
            case .success(let packet):
                // Persist RHR + episode via PolarManager helpers
                self.manager.submitPolar360SleepPacket(packet)
                self.manager.submitPolar360SleepStages(from: packet)
                NSLog("[SYNC] sleep packet persisted (RHR + staged episode) device=\(deviceId) nightEnd=\(packet.sleepEnd)")

            case .failure(let err):
                NSLog("[SYNC] fetch sleep FAILED device=\(deviceId): \(err.localizedDescription)")
            }
        }
    }
}

enum PolarCloudAPI {

    // Change this if you don’t want to use Info.plist
    static var defaultBaseURL: URL = {
        if let s = Bundle.main.object(forInfoDictionaryKey: "CTBackendBaseURL") as? String,
           let u = URL(string: s) { return u }
        // Fallback – replace with your real backend
        return URL(string: "https://api.your-backend.example")!
    }()

    enum APIError: LocalizedError {
        case noAuthToken
        case badURL
        case noData
        case http(Int)
        case decode(Error)

        var errorDescription: String? {
            switch self {
            case .noAuthToken: return "Missing access token"
            case .badURL:      return "Bad URL"
            case .noData:      return "No data"
            case .http(let c): return "HTTP error \(c)"
            case .decode(let e): return "Decoding failed: \(e.localizedDescription)"
            }
        }
    }

    /// GET /v1/polar360/sleep/last?deviceId=...
    /// Expects the server to return a JSON body that decodes into `P360SleepPacket`.
    static func fetchLastNightSleep(
        baseURL: URL = defaultBaseURL,
        deviceId: String,
        completion: @escaping (Swift.Result<P360SleepPacket, Error>) -> Void
    ) {
        guard let token = UserDefaults.standard.string(forKey: "accessToken"),
              !token.isEmpty else {
            NSLog("[PolarCloudAPI] no access token")
            completion(.failure(APIError.noAuthToken))
            return
        }

        var comps = URLComponents(url: baseURL.appendingPathComponent("/v1/polar360/sleep/last"),
                                  resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "deviceId", value: deviceId)]
        guard let url = comps?.url else {
            completion(.failure(APIError.badURL)); return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        NSLog("[PolarCloudAPI] GET \(url.absoluteString)")
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                NSLog("[PolarCloudAPI] network error: \(err.localizedDescription)")
                completion(.failure(err)); return
            }
            guard let http = resp as? HTTPURLResponse else {
                completion(.failure(APIError.noData)); return
            }
            guard (200..<300).contains(http.statusCode) else {
                NSLog("[PolarCloudAPI] HTTP \(http.statusCode)")
                completion(.failure(APIError.http(http.statusCode))); return
            }
            guard let data = data, !data.isEmpty else {
                completion(.failure(APIError.noData)); return
            }
            do {
                // Assuming P360SleepPacket : Codable
                let packet = try JSONDecoder.iso8601.decode(P360SleepPacket.self, from: data)
                completion(.success(packet))
            } catch {
                NSLog("[PolarCloudAPI] decode error: \(error.localizedDescription)")
                completion(.failure(APIError.decode(error)))
            }
        }.resume()
    }
}

//struct PolarCloudAPI {
//    let baseURL: URL
//    /// Return your bearer access token (from Keychain/UserDefaults/Session)
//    let tokenProvider: () -> String?
//
//    enum APIError: LocalizedError {
//        case notAuthenticated
//        case noData
//        case http(Int, String)
//        case decode(Error)
//        case network(Error)
//        case notFoundOrNotReady  // 404/204 while Polar hasn’t built the sleep yet
//
//        var errorDescription: String? {
//            switch self {
//            case .notAuthenticated: return "Missing access token."
//            case .noData: return "Empty server response."
//            case .http(let code, let msg): return "HTTP \(code): \(msg)"
//            case .decode(let e): return "Decode error: \(e.localizedDescription)"
//            case .network(let e): return "Network: \(e.localizedDescription)"
//            case .notFoundOrNotReady: return "Sleep not ready yet (404/204)."
//            }
//        }
//    }
//
//    func fetchLastNightSleep(
//        deviceId: String,
//        completion: @escaping (Result<P360SleepPacket, Error>) -> Void
//    ) {
//        guard let token = tokenProvider(), !token.isEmpty else {
//            NSLog("[CLOUD] No token; aborting sleep fetch")
//            completion(.failure(APIError.notAuthenticated))
//            return
//        }
//
//        // Adjust the path to match your backend.
//        // Example: GET /v1/polar360/devices/{id}/sleep/last-night
//        var url = baseURL
//        url.append(path: "/v1/polar360/devices/\(deviceId)/sleep/last-night")
//
//        var req = URLRequest(url: url)
//        req.httpMethod = "GET"
//        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//        req.setValue("application/json", forHTTPHeaderField: "Accept")
//
//        NSLog("[CLOUD] GET \(url.absoluteString)")
//
//        URLSession.shared.dataTask(with: req) { data, resp, err in
//            if let err = err {
//                NSLog("[CLOUD] network error: \(err)")
//                completion(.failure(APIError.network(err)))
//                return
//            }
//            guard let http = resp as? HTTPURLResponse else {
//                completion(.failure(APIError.noData)); return
//            }
//
//            // 204 No Content or 404 Not Found → no sleep yet (try again later)
//            if http.statusCode == 204 || http.statusCode == 404 {
//                NSLog("[CLOUD] sleep not ready yet (status \(http.statusCode))")
//                completion(.failure(APIError.notFoundOrNotReady))
//                return
//            }
//
//            guard (200..<300).contains(http.statusCode) else {
//                let body = String(data: data ?? Data(), encoding: .utf8) ?? ""
//                NSLog("[CLOUD] http \(http.statusCode) body=\(body)")
//                completion(.failure(APIError.http(http.statusCode, body)))
//                return
//            }
//
//            guard let data = data, !data.isEmpty else {
//                completion(.failure(APIError.noData)); return
//            }
//
//            do {
//                var packet = try JSONDecoder.iso8601.decode(P360SleepPacket.self, from: data)
//                // If server didn’t include quality_windows, synthesize a fair window
//                if packet.qualityWindows.isEmpty {
//                    let start = (packet.stages.min(by: { $0.start < $1.start })?.start)
//                             ?? (packet.motions.min(by: { $0.start < $1.start })?.start)
//                             ?? packet.sleepEnd.addingTimeInterval(-8*3600)
//                    let qwin = P360SleepPacket.QualityWindow(start: start, end: packet.sleepEnd, quality: .fair)
//                    packet = P360SleepPacket(
//                        hrSeries: packet.hrSeries,
//                        stages: packet.stages,
//                        motions: packet.motions,
//                        sleepEnd: packet.sleepEnd,
//                        qualityWindows: [qwin]
//                    )
//                }
//                NSLog("[CLOUD] decoded sleep packet nightEnd=\(packet.sleepEnd)")
//                completion(.success(packet))
//            } catch {
//                NSLog("[CLOUD] decode error: \(error)")
//                completion(.failure(APIError.decode(error)))
//            }
//        }.resume()
//    }
//}

// MARK: - JSONDecoder helper (ISO8601 + fractional seconds)

//private extension JSONDecoder {
//    static var iso8601: JSONDecoder = {
//        let d = JSONDecoder()
//        if #available(iOS 11.0, *) {
//            d.dateDecodingStrategy = .iso8601
//        } else {
//            let f = DateFormatter()
//            f.locale = Locale(identifier: "en_US_POSIX")
//            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
//            d.dateDecodingStrategy = .formatted(f)
//        }
//        return d
//    }()
//}
