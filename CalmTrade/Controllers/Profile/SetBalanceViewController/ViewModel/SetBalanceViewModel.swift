//
//  SetBalanceViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 29/10/25.
//

import Foundation

struct SetBalanceUI {
    let accountName: String
    let calculatedCurrentBalanceText: String
    let startingBalanceText: String
    let brokerCurrentBalanceText: String
}

final class SetBalanceViewModel: BaseViewModel {

    var onLoading: ((Bool) -> Void)?
    var onUI: ((SetBalanceUI) -> Void)?
    var onToast: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let api = APIService()

    // MARK: - DTOs (match new payload)
    private struct MoneyAmountDTO: Decodable {
        let numberDecimal: String
        enum CodingKeys: String, CodingKey { case numberDecimal = "$numberDecimal" }
    }
    private struct StartingBalanceDTO: Decodable {
        let amount: MoneyAmountDTO?
        let currency: String?
    }
    
    private struct CurrentBalanceDTO: Decodable {
        let amount: MoneyAmountDTO?
    }
    
    private struct AccountDTO: Decodable {
        let _id: String?
        let userId: String?
        let broker: String?
        let timezone: String?
        let updatedAt: String?
        let createdAt: String?
        let accountName: String?
        let isActive: Bool?
        let __v: Int?
        let startingBalance: StartingBalanceDTO?
        let currentBalance: CurrentBalanceDTO?
        let brokerCurrentBalance: CurrentBalanceDTO?
    }
    private struct AccountsResponse: Decodable {
        let success: Bool?
        let accounts: [AccountDTO]?
        let count: Int?
        let status: Int?
    }
    private struct GenericResponse: Decodable { let success: Bool?; let message: String? }

    // MARK: - GET (keeps your latest endpoint constant)
    func load() {
        onLoading?(true)
        api.startService(with: .GET,
                         path: Endpoints.Users.getBalance.rawValue,
                         parameters: nil,
                         files: nil,
                         modelType: AccountsResponse.self) { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoading?(false)
                switch result {
                case .Success(let resp):
                    guard let acct = resp?.accounts?.first(where: {$0.broker == "Webull"}) else {
                        self?.onError?("No account found."); return
                    }
                    let name = acct.accountName ?? "—"
                    let startPlain = acct.startingBalance?.amount?.numberDecimal ?? "0"

                    // Map currentBalance → label text with $
                    let currPlain = acct.currentBalance?.amount?.numberDecimal ?? "0"
                    
                    let brokerCurrentBalance = acct.brokerCurrentBalance?.amount?.numberDecimal ?? "0"

                    let ui = SetBalanceUI(
                        accountName: name,
                        calculatedCurrentBalanceText: Self.normalize(currPlain),
                        startingBalanceText: Self.normalize(startPlain), brokerCurrentBalanceText: Self.normalize(brokerCurrentBalance)
                    )
                    self?.onUI?(ui)

                case .Error(let msg):
                    self?.onError?(msg)
                }
            }
        }
    }

    // MARK: - POST (keeps your latest endpoint constant)
    func saveStartingBalance(from startingText: String,
                             accountName: String,
                             currency: String = "USD",
                             timezone: String = TimeZone.current.identifier,
                             broker: String = "Manual",
                             brokerCurrentBalance: String) {
        let amount = Double(startingText.replacingOccurrences(of: "$", with: "")
                                      .trimmingCharacters(in: .whitespaces)) ?? 0
        let params: [String: Any] = [
            "startingBalance": amount,
            "brokerCurrentBalance": brokerCurrentBalance
        ]

        onLoading?(true)
        api.startService(with: .POST,
                         path: Endpoints.Users.setBalance.rawValue,
                         parameters: params,
                         files: nil,
                         modelType: GenericResponse.self) { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoading?(false)
                switch result {
                case .Success:
                    self?.onToast?("Analytics updated. Current Balance saved.")
                    self?.load()
                case .Error(let msg):
                    self?.onError?(msg.isEmpty ? "Couldn’t save changes. Please try again." : msg)
                }
            }
        }
    }

    // OPTIONAL: override balance (update path to your Endpoints constant when available)
    func patchCurrentBalance(amountText: String, currency: String = "USD", reason: String? = nil) {
        let amount = Double(amountText.replacingOccurrences(of: "$", with: "")
                                      .trimmingCharacters(in: .whitespaces)) ?? 0
        var params: [String: Any] = ["amount": amount, "currency": currency]
        if let reason, !reason.isEmpty { params["reason"] = reason }

        onLoading?(true)
        api.startService(with: .PUT,
                         path: "/acc/balance/current-balance", // TODO: replace with Endpoints.Users.patchCurrentBalance when defined
                         parameters: params,
                         files: nil,
                         modelType: GenericResponse.self) { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoading?(false)
                switch result {
                case .Success:
                    self?.onToast?("Analytics updated. Current Balance saved.")
                    self?.load()
                case .Error(let msg):
                    self?.onError?(msg.isEmpty ? "Couldn’t save changes. Please try again." : msg)
                }
            }
        }
    }

    // MARK: - Helpers
    private static func normalize(_ s: String) -> String {
        // Keep it simple: format to max 2 decimals; trim trailing .00
        if let dec = Decimal(string: s) {
            let ns = NSDecimalNumber(decimal: dec)
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.maximumFractionDigits = 2
            f.minimumFractionDigits = dec.isWholeNumber ? 0 : 2
            return f.string(from: ns) ?? s
        }
        return s
    }
}

private extension Decimal {
    var isWholeNumber: Bool {
        NSDecimalNumber(decimal: self).doubleValue.rounded(.towardZero)
        == NSDecimalNumber(decimal: self).doubleValue
    }
}
