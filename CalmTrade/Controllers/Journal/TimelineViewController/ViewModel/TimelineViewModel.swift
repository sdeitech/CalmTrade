//
//  TimelineViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/01/26.
//

import Foundation
import UIKit
import KRProgressHUD

final class TimelineViewModel {

    var onReload: (() -> Void)?
    var onError: ((String) -> Void)?
    var onSummary: ((NSAttributedString) -> Void)?
    
    var selectedDate: String = "2026-01-13"

    private(set) var items: [TimelineItem] = []
    private let api: ApiServiceProtocol = APIService()
    
    private var hasJournalAccess: Bool {
        switch FeatureGate.shared.access(for: FeatureKey.journalUnlocked) {
        case .allowed: true
        case .locked: false
        }
    }

    func fetch() {
        let param = ["date": selectedDate]
        LoaderManager.shared.show()
        api.startService(
            with: .GET,
            path: "session/timeline",
            parameters: param,
            files: nil,
            modelType: TimelineResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                LoaderManager.shared.hide()
                switch result {
                case .Success(let response):
                    guard let data = response?.data else {
                        self?.items = []
                        self?.onSummary?(Self.emptySummary())
                        self?.onReload?()
                        return
                    }
                    self?.items = data.timeline
                    self?.onSummary?(Self.makeSummary(from: data.sessionSummary))
                    self?.onReload?()
                case .Error(let msg):
                    self?.items = []
                    self?.onSummary?(Self.emptySummary())
                    self?.onReload?()
                    self?.onError?(msg)
                }
            }
        }
    }


    func displayItem(at index: Int) -> TimelineDisplayItem {
        displayItems[index]
    }
    
    var displayItems: [TimelineDisplayItem] {
        guard !hasJournalAccess else {
            return items.map { .entry($0) }
        }

        // Locked logic
        var result: [TimelineDisplayItem] = []

        let grouped = Dictionary(grouping: items) { item -> TimelineItemType in
            item.type
        }

        for type in [TimelineItemType.trade,
                     TimelineItemType.emotion,
                     TimelineItemType.noTrade] {

            if let latest = grouped[type]?.sorted(by: {
                ($0.timestamp ?? "") > ($1.timestamp ?? "")
            }).first {
                result.append(.entry(latest))
            }
        }

        if !result.isEmpty {
            result.append(.viewAllLocked)
        }

        return result
    }

    var count: Int { displayItems.count }
    
    func deleteItem(item: TimelineItem, completion: @escaping (Bool) -> Void) {

        guard let id = item._id else {
            completion(false)
            return
        }

        let typePath: String

        switch item.type {
        case .trade:
            typePath = "trade"
        case .emotion:
            typePath = "emotion"
        case .noTrade:
            typePath = "notrade"
        case .unknown:
            completion(false)
            return
        }

        let path = "session/timeline/\(typePath)/\(id)"

        api.startService(
            with: .DELETE,
            path: path,
            parameters: nil,
            files: nil,
            modelType: EmptyResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .Success:
                    self?.fetch()
                    completion(true)
                case .Error:
                    completion(false)
                }
            }
        }
    }

}

extension TimelineViewModel {

    static func makeSummary(from s: SessionSummary?) -> NSAttributedString {
        guard let s else {
            return emptySummary()
        }

        let result = NSMutableAttributedString()
        
        // MARK: - Helpers
        
        func titleAttr(_ text: String) -> NSAttributedString {
            NSAttributedString(
                string: text,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: UIColor.init(hex: "CACACA")
                ]
            )
        }
        
        func valueAttr(_ text: String) -> NSAttributedString {
            NSAttributedString(
                string: text,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
            )
        }
        
        func divider() -> NSAttributedString {
            NSAttributedString(
                string: "  |  ",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 14),
                    .foregroundColor: UIColor.init(hex: "CACACA")
                ]
            )
        }
        
        func addPair(_ title: String, _ value: String, addDivider: Bool) {
            let pair = NSMutableAttributedString()
            pair.append(titleAttr("\(title): "))
            pair.append(valueAttr(value))
            
            if addDivider {
                pair.append(divider())
            }
            
            result.append(pair)
        }
        
        // MARK: - Existing pairs
        
        addPair("P/L", String(format: "$%.2f", s.pnl), addDivider: true)
        addPair("Trade", "\(s.trades)", addDivider: s.sleep != nil || s.calmScore != nil)
        
        if let sleep = s.sleep {
            addPair("Sleep", "\(sleep) hr", addDivider: s.calmScore != nil)
        }
        
        if let calmScore = s.calmScore {
            addPair("CalmScore", "\(calmScore)", addDivider: false)
        }
        
        // MARK: - Risk limits
        
        if result.length > 0 {
            result.append(NSAttributedString(string: "\n\n"))
        }

        // Header
        result.append(
            NSAttributedString(
                string: "Risk Limits:\n",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: UIColor.init(hex: "CACACA")
                ]
            )
        )

        // Helpers specific to risk lines
        func boldAttr(_ text: String) -> NSAttributedString {
            NSAttributedString(
                string: text,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
            )
        }

        func normalAttr(_ text: String) -> NSAttributedString {
            NSAttributedString(
                string: text,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: UIColor.init(hex: "CACACA")
                ]
            )
        }

        func bulletLine(title: String, rValue: String, dollarValue: String) -> NSAttributedString {
            let line = NSMutableAttributedString()
            line.append(normalAttr("• "))
            line.append(boldAttr("\(title): \(rValue)R "))
            line.append(normalAttr("(≈ $\(dollarValue))\n"))
            return line
        }

        // Values
        let maxSessionR = s.riskLimits?.maxLossPerSessionR ?? 0.0
        let maxSessionDollar = s.riskLimits?.maxLossPerSession ?? 0.0

        let maxTradeR = s.riskLimits?.maxLossPerTradeR ?? 0.0
        let maxTradeDollar = s.riskLimits?.maxLossPerTrade ?? 0.0

        // Lines
        result.append(
            bulletLine(
                title: "Max loss per session",
                rValue: "\(maxSessionR)",
                dollarValue: String(format: "%.2f", maxSessionDollar)
            )
        )

        result.append(
            bulletLine(
                title: "Max loss per trade",
                rValue: "\(maxTradeR)",
                dollarValue: String(format: "%.2f", maxTradeDollar)
            )
        )
        
        return result
    }

    static func emptySummary() -> NSAttributedString {
        NSAttributedString(
            string: "No data found for selected date.",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.init(hex: "CACACA")
            ]
        )
    }
}


enum TimelineDisplayItem {
    case entry(TimelineItem)
    case viewAllLocked
}
