//
//  StartSessionViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/12/25.
//

import Foundation

final class StartSessionViewModel {

    // MARK: - Outputs
    var onDefaultsApplied: ((String, String) -> Void)?
    var onUseDefaultEnabled: ((Bool) -> Void)?
    var onSaveEnabled: ((Bool) -> Void)?
    var onLoading: ((Bool) -> Void)?
    var onSuccess: (() -> Void)?
    var onError: ((String) -> Void)?

    // MARK: - Private
    private let api: ApiServiceProtocol

    private var currentTradeLoss: Double?
    private var currentSessionLoss: Double?
    private var didUserEdit = false

    // MARK: - UserDefaults Keys
    let tradeKey = "ct.maxLossPerTrade"
    let sessionKey = "ct.maxLossPerSession"
    
    private var defaultTradeLoss: Double?
    private var defaultSessionLoss: Double?

    // MARK: - Init
    init(api: ApiServiceProtocol = APIService()) {
        self.api = api
    }

    // MARK: - Lifecycle
    func viewDidLoad() {
        let trade = UserDefaults.standard.object(forKey: tradeKey) as? Double
        let session = UserDefaults.standard.object(forKey: sessionKey) as? Double

        if let trade, let session {
            currentTradeLoss = trade
            currentSessionLoss = session
            onDefaultsApplied?("\(trade)", "\(session)")
            onUseDefaultEnabled?(true)
        } else {
            onUseDefaultEnabled?(false)
        }

        // Save stays disabled until user edits
        onSaveEnabled?(false)
        fetchPreviousRiskLimits()
    }

    // MARK: - User Actions
    func useDefaultsTapped() {
        guard
            let trade = defaultTradeLoss,
            let session = defaultSessionLoss
        else { return }

        currentTradeLoss = trade
        currentSessionLoss = session
        didUserEdit = true

        onDefaultsApplied?("\(trade)", "\(session)")
        validateSaveState()
    }

    func tradeLossChanged(_ text: String) {
        currentTradeLoss = Double(text)
        didUserEdit = true
        validateSaveState()
    }

    func sessionLossChanged(_ text: String) {
        currentSessionLoss = Double(text)
        didUserEdit = true
        validateSaveState()
    }
    
    private func fetchPreviousRiskLimits() {
        onLoading?(true)

        api.startService(
            with: .GET,
            path: "session/previous-risk-limits",
            parameters: nil,
            files: nil,
            modelType: PreviousRiskLimitsResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoading?(false)

                switch result {
                case .Success(let response):
                    guard
                        response?.success == true,
                        let data = response?.data
                    else {
                        self?.onUseDefaultEnabled?(false)
                        return
                    }

                    self?.defaultTradeLoss = data.maxLossPerTrade
                    self?.defaultSessionLoss = data.maxLossPerSession

                    self?.currentTradeLoss = data.maxLossPerTrade
                    self?.currentSessionLoss = data.maxLossPerSession

                    self?.onDefaultsApplied?(
                        "\(data.maxLossPerTrade)",
                        "\(data.maxLossPerSession)"
                    )

                    self?.onUseDefaultEnabled?(true)

                case .Error:
                    self?.onUseDefaultEnabled?(false)
                }
            }
        }
    }


    func saveTapped() {
        guard didUserEdit else { return }

        guard let trade = currentTradeLoss, trade > 0,
              let session = currentSessionLoss, session > 0 else {
            onError?("Please enter valid values")
            return
        }

        onLoading?(true)

        let params: [String: Any] = [
            "maxLossPerTrade": trade,
            "maxLossPerSession": session
        ]

        api.startService(
            with: .POST,
            path: "session/start",
            parameters: params,
            files: nil,
            modelType: StartSessionResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoading?(false)

                switch result {
                case .Success(let response):
                    if response?.success == false {
                        self?.onError?(response?.message ?? "Something went wrong")
                        return
                    }

                    // Persist defaults for future sessions
                    UserDefaults.standard.set(trade, forKey: self!.tradeKey)
                    UserDefaults.standard.set(session, forKey: self!.sessionKey)
                    UserDefaults.standard.set(Date(), forKey: "ct.lastSessionSetupDate")

                    self?.onSuccess?()

                case .Error(let message):
                    self?.onError?(message)
                }
            }
        }
    }

    // MARK: - Validation
    private func validateSaveState() {
        guard didUserEdit,
              let trade = currentTradeLoss, trade > 0,
              let session = currentSessionLoss, session > 0 else {
            onSaveEnabled?(false)
            return
        }
        onSaveEnabled?(true)
    }
}

