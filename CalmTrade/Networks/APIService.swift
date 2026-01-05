//
//  APIService.swift
//  iOSArchitecture
//
//  Created by Amit on 23/02/18.
//  Updated by ChatGPT on 22/09/25.
//  © 2018 smartData. All rights reserved.
//

import Foundation
import UIKit
import os.log

// MARK: - HTTP

public enum HttpMethod: String {
    case POST, GET, PUT, DELETE
}

private enum ResponseCode: Int {
    case success = 200
}

// MARK: - Public payloads

public struct File {
    public let name: String?
    public let filename: String?
    public let data: Data?
    public let mimeType: String?

    public init(name: String?, filename: String?, data: Data?, mimeType: String? = "application/octet-stream") {
        self.name = name
        self.filename = filename
        self.data = data
        self.mimeType = mimeType
    }
}

// Using a custom Result for backward compatibility with the project.
public enum Result<T> {
    case Success(T)
    case Error(String)
}

// MARK: - Protocol

public protocol ApiServiceProtocol {
    func startService<T: Decodable>(
        with method: HttpMethod,
        path: String,
        parameters: [String: Any]?,
        files: [File]?,
        modelType: T.Type,
        completion: @escaping (Result<T?>) -> Void
    )

    func buildRequest(
        with method: HttpMethod,
        url: URL,
        parameters: [String: Any]?,
        files: [File]?
    ) -> URLRequest

    func buildParams(parameters: [String: Any]) -> String

    func handleResponse<T: Decodable>(
        data: Data,
        response: URLResponse?,
        modelType: T.Type,
        completion: @escaping (Result<T?>) -> Void
    )
}

// MARK: - Service

public class APIService: NSObject, ApiServiceProtocol {

    public func startService<T: Decodable>(
        with method: HttpMethod,
        path: String,
        parameters: [String: Any]?,
        files: [File]?,
        modelType: T.Type,
        completion: @escaping (Result<T?>) -> Void
    ) {
        // Fast fail when offline
        if !isInternetReachable() {
            completion(.Error(AlertMessage.LOST_INTERNET))
            return
        }

        guard let url = URL(string: BuildConfig.baseURL + path) else {
            completion(.Error(AlertMessage.INVALID_URL))
            return
        }

        var request = buildRequest(with: method, url: url, parameters: parameters, files: files)

        // ⬇️ Ensure Authorization header exists (pulls from UserDefaults if missing)
        injectAuthIfMissing(&request)

        // Log and proceed…
        NetworkLogger.logRequest(request, explicitParams: parameters, attachedFiles: files)
        let startedAt = Date()
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            NetworkLogger.logResponse(request: request,
                                      data: data,
                                      response: response as? HTTPURLResponse,
                                      error: error,
                                      startedAt: startedAt)
            if let error { return completion(.Error(error.localizedDescription)) }
            guard let data = data else { return completion(.Error("Data not found.")) }
            self.handleResponse(data: data, response: response, modelType: modelType, completion: completion)
        }
        task.resume()
    }
}

// MARK: - Request building

public extension APIService {

    func buildRequest(
        with method: HttpMethod,
        url: URL,
        parameters: [String: Any]?,
        files: [File]?
    ) -> URLRequest {

        var req: URLRequest

        switch method {
        case .GET:
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false) ?? URLComponents()
            if let params = parameters, !params.isEmpty {
                components.queryItems = params.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
            }
            req = URLRequest(url: components.url ?? url)

        case .POST, .PUT:
            req = URLRequest(url: url)

            if let images = files, !images.isEmpty {
                // Multipart
                let boundary = "Boundary-\(UUID().uuidString)"
                req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

                let body = NSMutableData()
                if let params = parameters, !params.isEmpty {
                    for (key, value) in params {
                        body.append("--\(boundary)\r\n".nsdata)
                        body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".nsdata)
                        body.append("\(value)\r\n".nsdata)
                    }
                }
                for file in images {
                    guard let name = file.name, let filename = file.filename, let data = file.data else { continue }
                    let mime = file.mimeType ?? "application/octet-stream"
                    body.append("--\(boundary)\r\n".nsdata)
                    body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".nsdata)
                    body.append("Content-Type: \(mime)\r\n\r\n".nsdata)
                    body.append(data)
                    body.append("\r\n".nsdata)
                }
                body.append("--\(boundary)--\r\n".nsdata)
                req.httpBody = body as Data

            } else if let params = parameters, !params.isEmpty {
                // JSON body
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])
            }

        case .DELETE:
            // Often either query params or JSON body; using JSON body here if params present
            req = URLRequest(url: url)
            if let params = parameters, !params.isEmpty {
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])
            }
        }

        // Common headers
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        // Authorization
        if let token = UserDefaults.standard.string(forKey: "accessToken") {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        

        req.httpMethod = method.rawValue
        return req
    }

    func buildParams(parameters: [String: Any]) -> String {
        var components: [(String, String)] = []
        for (key, value) in parameters {
            components += queryComponents(key, value)
        }
        return components.map { "\($0)=\($1)" }.joined(separator: "&")
    }

    func queryComponents(_ key: String, _ value: Any) -> [(String, String)] {
        var components: [(String, String)] = []
        if let dictionary = value as? [String: Any] {
            for (nestedKey, value) in dictionary {
                components += queryComponents("\(key)[\(nestedKey)]", value)
            }
        } else if let array = value as? [Any] {
            for value in array {
                components += queryComponents("\(key)", value)
            }
        } else {
            components.append((escape(string: key), escape(string: "\(value)")))
        }
        return components
    }

    func escape(string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }
}

// MARK: - Response handling

public extension APIService {

    func handleResponse<T: Decodable>(
        data: Data,
        response: URLResponse?,
        modelType: T.Type,
        completion: @escaping (Result<T?>) -> Void
    ) {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1

        if (200...299).contains(status) {
            do {
                let decoded = try JSONDecoder().decode(modelType, from: data)
                completion(.Success(decoded))
            } catch {
                print("❌ Decoding failed for \(modelType):", error)
                print("❌ Raw response:", String(data: data, encoding: .utf8) ?? "<not UTF8>")
                completion(.Error(error.localizedDescription))
            }
            return
        }

        // Extract readable error message if possible
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            let message = (json["message"] as? String)
                ?? (json["error"] as? String)
                ?? (json["detail"] as? String)
                ?? "HTTP \(status)"
            completion(.Error(message))
        } else {
            completion(.Error("HTTP \(status)"))
        }
    }
}

// MARK: - Helpers

private extension String {
    var nsdata: Data { data(using: .utf8, allowLossyConversion: false)! }
}

// MARK: - Network Logger

/// Logs the FULL request/response for every API call:
/// - Request line (method + URL)
/// - Headers (with sensitive values redacted)
/// - Params/body (pretty JSON when possible; multipart summarized)
/// - An equivalent `curl` command
/// - Response status code, headers, and the full JSON/body
/// - Timing (latency) and payload sizes
enum NetworkLogger {
//    #if DEBUG
    private static let enabled = true
//    #else
//    private static let enabled = true
//    #endif

    // Anything here will have its value replaced with "***"
    private static let redactedHeaderKeys: Set<String> = [
        "authorization",
        "x-api-key",
        "x-auth-token"
    ]

    static func logRequest(_ request: URLRequest,
                           explicitParams: [String: Any]?,
                           attachedFiles: [File]?) {
        guard enabled else { return }

        var lines: [String] = []
        lines.append("➡️➡️➡️ [REQUEST]")
        lines.append("• \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")

        // Headers
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            lines.append("• Headers:")
            for (k, v) in headers {
                let redacted = redactedHeaderKeys.contains(k.lowercased()) ? "***" : v
                lines.append("    \(k): \(redacted)")
            }
        }

        // Params/body (best-effort)
        if let files = attachedFiles, !files.isEmpty {
            lines.append("• Body: multipart/form-data (\(files.count) part(s))")
            files.forEach { file in
                let size = file.data?.count ?? 0
                lines.append("    • \(file.name ?? "?") filename=\(file.filename ?? "?") mime=\(file.mimeType ?? "application/octet-stream") size=\(size) bytes")
            }
            if let params = explicitParams, !params.isEmpty {
                lines.append("• Fields:")
                lines.append(pretty(params))
            }
        } else if let body = request.httpBody, !body.isEmpty {
            if let jsonObj = try? JSONSerialization.jsonObject(with: body, options: []) {
                lines.append("• Body (JSON):")
                lines.append(pretty(jsonObj))
            } else if let text = String(data: body, encoding: .utf8) {
                lines.append("• Body (raw):")
                lines.append(indent(text))
            } else {
                lines.append("• Body: <\(body.count) bytes>")
            }
        } else if let params = explicitParams, !params.isEmpty, request.httpMethod == "GET" {
            lines.append("• Query Params:")
            lines.append(pretty(params))
        }

        // cURL
        lines.append("• cURL:")
        lines.append(indent(curlString(from: request)))

        print(lines.joined(separator: "\n"))
    }

    static func logResponse(request: URLRequest,
                            data: Data?,
                            response: HTTPURLResponse?,
                            error: Error?,
                            startedAt: Date) {
        guard enabled else { return }

        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)

        var lines: [String] = []
        lines.append("⬅️⬅️⬅️ [RESPONSE]")
        lines.append("• \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        lines.append("• Time: \(elapsedMs) ms")

        if let response {
            lines.append("• Status: \(response.statusCode)")
            if !response.allHeaderFields.isEmpty {
                lines.append("• Headers:")
                response.allHeaderFields.forEach { k, v in
                    lines.append("    \(k): \(v)")
                }
            }
        }

        if let error {
            lines.append("• Error: \(error.localizedDescription)")
        }

        if let data {
            if let obj = try? JSONSerialization.jsonObject(with: data, options: []) {
                lines.append("• Body (JSON):")
                lines.append(pretty(obj))
            } else if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                lines.append("• Body (raw):")
                lines.append(indent(text))
            } else {
                lines.append("• Body: <\(data.count) bytes>")
            }
        } else {
            lines.append("• Body: <empty>")
        }

        print(lines.joined(separator: "\n"))
    }

    // MARK: Pretty helpers

    private static func pretty(_ obj: Any) -> String {
        if let dict = obj as? [String: Any] {
            if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .withoutEscapingSlashes]),
               let str = String(data: data, encoding: .utf8) {
                return indent(str)
            }
        } else if let arr = obj as? [Any] {
            if let data = try? JSONSerialization.data(withJSONObject: arr, options: [.prettyPrinted, .withoutEscapingSlashes]),
               let str = String(data: data, encoding: .utf8) {
                return indent(str)
            }
        } else if let data = obj as? Data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []),
                  let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .withoutEscapingSlashes]),
                  let str = String(data: pretty, encoding: .utf8) {
            return indent(str)
        }
        return indent(String(describing: obj))
    }

    private static func indent(_ s: String) -> String {
        return s.split(separator: "\n").map { "    " + $0 }.joined(separator: "\n")
    }

    private static func curlString(from request: URLRequest) -> String {
        var parts: [String] = ["curl"]

        // Method
        let method = request.httpMethod ?? "GET"
        if method != "GET" { parts += ["-X", shellEscape(method)] }

        // Headers
        if let headers = request.allHTTPHeaderFields {
            for (k, v) in headers {
                let value = redactedHeaderKeys.contains(k.lowercased()) ? "***" : v
                parts += ["-H", shellEscape("\(k): \(value)")]
            }
        }

        // Body
        if let data = request.httpBody, !data.isEmpty {
            if let bodyString = String(data: data, encoding: .utf8) {
                parts += ["--data-raw", shellEscape(bodyString)]
            } else {
                parts += ["--data-binary", shellEscape("<\(data.count) bytes binary>")]
            }
        }

        // URL
        if let url = request.url?.absoluteString {
            parts.append(shellEscape(url))
        }

        return parts.joined(separator: " ")
    }

    private static func shellEscape(_ s: String) -> String {
        // Simple POSIX-friendly shell escaping
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

private extension URLRequest {
    var hasAuthorizationHeader: Bool {
        (allHTTPHeaderFields?["Authorization"]?.isEmpty == false)
        || (allHTTPHeaderFields?["authorization"]?.isEmpty == false)
    }
}

private extension APIService {
    func injectAuthIfMissing(_ request: inout URLRequest) {
        guard !request.hasAuthorizationHeader,
              let token = UserDefaults.standard.string(forKey: "accessToken"),
              !token.isEmpty else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}
