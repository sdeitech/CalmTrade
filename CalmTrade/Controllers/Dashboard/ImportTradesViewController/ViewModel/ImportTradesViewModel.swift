//
//  ImportTradesViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/11/25.
//

import Foundation
import UIKit

final class ImportTradesViewModel: BaseViewModel {
    
    // MARK: - Closures
    var onLoading: ((Bool) -> Void)?
    var onToast: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onImportSuccess: (() -> Void)?
    var onBrokerConnect: ((String) -> Void)?
    var onAccountsLoaded: (([SnapTradeAccount]) -> Void)?
    
    // MARK: - Data
    private let api = APIService()
    var connectedAccounts: [SnapTradeAccount] = []
    
    var selectedBroker: String = "Generic Import Format"
    var selectedTimezone: String?
    var accountName: String = ""
    var shouldAlwaysRequireAccount: Bool = false
    var selectedFileData: Data?
    var selectedFileName: String?
    var selectedFileMime: String?
    
    // MARK: - Import File Mode
    func validateAndImport() {
        
        guard let tz = selectedTimezone else {
            onError?("Please select your local time zone.")
            return
        }
        
        guard !accountName.isEmpty else {
            onError?("Please enter your account name.")
            return
        }
        
        guard let fileData = selectedFileData,
              let fileName = selectedFileName else {
            onError?("Please select a trade file to upload.")
            return
        }
        
        let mime = selectedFileMime ?? "application/octet-stream"
        let req = ImportTradesRequest(accountName: accountName,
                                      broker: selectedBroker,
                                      timezone: tz,
                                      fileData: fileData,
                                      fileName: fileName,
                                      mimeType: mime)
        
        importTrades(request: req)
    }
    
    private func importTrades(request: ImportTradesRequest) {
        onLoading?(true)
        
        let file = File(name: "file",
                        filename: request.fileName,
                        data: request.fileData,
                        mimeType: request.mimeType)
        
        let params: [String: Any] = [
            "accountName": request.accountName,
            "broker": request.broker,
            "timezone": request.timezone
        ]
        
        api.startService(with: .POST,
                         path: Endpoints.Users.importTrades.rawValue,
                         parameters: params,
                         files: [file],
                         modelType: ImportTradesResponse.self) { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoading?(false)
                
                switch result {
                case .Success(let model):
                    guard let m = model else { return }
                    if m.success == true {
                        self?.onToast?(m.message ?? "Import successful.")
                        self?.onImportSuccess?()
                    } else {
                        self?.onError?(m.message ?? "Import failed.")
                    }
                    
                case .Error(let msg):
                    self?.onError?(msg)
                }
            }
        }
    }
    
    // MARK: - Broker Sync
    func connectBroker() {
        onLoading?(true)
        
        api.startService(with: .GET,
                         path: Endpoints.Users.connectBroker.rawValue,
                         parameters: nil,
                         files: [],
                         modelType: BrokerConnectResponse.self) { [weak self] result in
            
            DispatchQueue.main.async {
                self?.onLoading?(false)
                
                switch result {
                case .Success(let model):
                    guard let m = model, m.success == true else {
                        self?.onError?("Failed to connect broker.")
                        return
                    }
                    
                    if let redirect = m.data?.redirectURI {
                        self?.onBrokerConnect?(redirect)
                    } else {
                        self?.onError?("Missing redirect URL.")
                    }
                    
                case .Error(let msg):
                    self?.onError?(msg)
                }
            }
        }
    }
    
    func callBrokerCallbackAndSync(completion: @escaping (Bool) -> Void) {
        onLoading?(true)

        api.startService(
            with: .POST,
            path: "broker/callback",
            parameters: nil,
            files: nil,
            modelType: BrokerCallbackResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoading?(false)

                switch result {
                case .Success(let model):
                    guard
                        let m = model,
                        m.success == true,
                        let accountId = m.data?.accounts?.first?.accountId
                    else {
                        completion(false)
                        return
                    }

                    // 🔥 IMMEDIATE BROKER SYNC
                    self?.syncBroker(accountId: accountId, fullSync: true)
                    completion(true)

                case .Error:
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - GET /broker/accounts/snaptrade
    func fetchConnectedAccounts() {
        
        onLoading?(true)
        
        api.startService(with: .GET,
                         path: "broker/accounts/snaptrade",
                         parameters: nil,
                         files: [],
                         modelType: SnapTradeAccountsResponse.self) { [weak self] result in
            
            DispatchQueue.main.async {
                self?.onLoading?(false)
                
                switch result {
                case .Success(let model):
                    guard let m = model else { return }
                    
                    if m.success == true {
                        self?.connectedAccounts = m.data ?? []
                        self?.onAccountsLoaded?(m.data ?? [])
                    } else {
                        self?.connectedAccounts = []
                        self?.onAccountsLoaded?([])
                    }
                    
                case .Error(let msg):
                    self?.connectedAccounts = []
                    self?.onError?(msg)
                }
            }
        }
    }
    
    func syncBroker(accountId: String, fullSync: Bool = true) {
        onLoading?(true)

        let params: [String: Any] = [
            "accountId": accountId,
            "fullSync": fullSync
        ]

        api.startService(
            with: .POST,
            path: "broker/sync",
            parameters: params,
            files: nil,
            modelType: BrokerSyncResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoading?(false)

                switch result {
                case .Success(let model):
                    guard model?.success == true else {
                        self?.onError?(model?.message ?? "Broker sync failed.")
                        return
                    }
                    self?.onToast?("Broker sync started")

                case .Error(let msg):
                    self?.onError?(msg)
                }
            }
        }
    }
}

