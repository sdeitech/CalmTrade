//
//  LocalTimeZoneViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 30/10/25.
//

import Foundation

final class LocalTimeZoneViewModel {

    // MARK: - Outputs
    var onDataReload: (() -> Void)?
    var onError: ((String) -> Void)?
    var onSuccess: ((String) -> Void)?

    // MARK: - Data
    private(set) var allZones: [LocalTimeZoneModel] = []
    private(set) var filteredZones: [LocalTimeZoneModel] = []
    private let apiService = APIService()

    // MARK: - Load Zones
    func loadZones() {
        guard let url = Bundle.main.url(forResource: "calmtrade_timezones_curated", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            onError?("Unable to load timezone list.")
            return
        }

        do {
            let zones = try JSONDecoder().decode([LocalTimeZoneModel].self, from: data)
            allZones = zones
            filteredZones = zones
            onDataReload?()
        } catch {
            onError?(error.localizedDescription)
        }
    }

    // MARK: - Search
    func search(_ query: String) {
        if query.isEmpty {
            filteredZones = allZones
        } else {
            let lower = query.lowercased()
            filteredZones = allZones.filter {
                $0.friendlyName.lowercased().contains(lower) ||
                $0.tzid.lowercased().contains(lower) ||
                $0.labelNow.lowercased().contains(lower)
            }
        }
        onDataReload?()
    }

    // MARK: - Select Zone (stubbed API)
    func selectZone(_ zone: LocalTimeZoneModel) {
        let params = ["timezone": zone.tzid]
        apiService.startService(with: .POST,
                                path: "user/set-timezone", // placeholder
                                parameters: params,
                                files: nil,
                                modelType: EmptyResponse.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .Success:
                    self.onSuccess?("Time zone updated to \(zone.friendlyName)")
                case .Error(let msg):
                    self.onError?(msg)
                }
            }
        }
    }
}

// Empty decodable response for now
struct EmptyResponse: Codable {}
