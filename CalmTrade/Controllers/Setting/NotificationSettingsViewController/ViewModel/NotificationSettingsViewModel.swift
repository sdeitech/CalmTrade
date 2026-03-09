//
//  NotificationSettingsViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/02/26.
//


import Foundation
import KRProgressHUD

final class NotificationSettingsViewModel {

    // MARK: - Outputs
    var onSettingsFetched: ((NotificationSettings) -> Void)?
    var onError: ((String) -> Void)?

    // MARK: - State
    private(set) var settings: NotificationSettings?
    private let api: ApiServiceProtocol = APIService()

    // Prevent rapid toggle spam
    private var pendingWorkItem: DispatchWorkItem?

    // MARK: - Fetch
    func fetchSettings() {
        LoaderManager.shared.show()

        api.startService(
            with: .GET,
            path: "notif/settings",
            parameters: nil,
            files: nil,
            modelType: NotificationSettingsResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                LoaderManager.shared.hide()

                switch result {
                case .Success(let response):
                    guard let settings = response?.data.settings else { return }
                    self?.settings = settings
                    self?.onSettingsFetched?(settings)

                case .Error(let message):
                    self?.onError?(message)
                }
            }
        }
    }

    // MARK: - Update
    func updateSetting(
        _ keyPath: WritableKeyPath<NotificationSettings, Bool>,
        value: Bool
    ) {
        guard var current = settings else { return }
        current[keyPath: keyPath] = value
        settings = current

        // Cancel previous pending update
        pendingWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.sendUpdate()
        }

        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
    }

    private func sendUpdate() {
        guard let params = settings?.toParams() else { return }

        LoaderManager.shared.show()

        api.startService(
            with: .PATCH,
            path: "notif/updateSettings",
            parameters: params,
            files: nil,
            modelType: NotificationSettingsResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                LoaderManager.shared.hide()

                switch result {
                case .Success(let response):
                    self?.settings = response?.data.settings

                case .Error(let message):
                    self?.onError?(message)
                }
            }
        }
    }
}
