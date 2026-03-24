//
//  ScannerViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 18/03/26.
//


import Foundation

final class ScannerViewModel {

    private(set) var items: [ScannerItem] = []
    var onUpdate: (() -> Void)?

    private let highlightDuration: TimeInterval = 4
    private var timer: Timer?
    private var mockTimer: Timer?

    // MARK: - Initial Load
    func loadInitialData() {
        items = (1...10).map {
            ScannerItem(
                symbol: "STK\($0)",
                pctUp: Double.random(in: 5...50),
                lastPrice: Double.random(in: 5...20),
                high: Double.random(in: 10...25),
                low: Double.random(in: 1...5),
                volume: Int.random(in: 10_000...90_000),
                floatShares: Int.random(in: 1_000_000...9_000_000),
                rvo: Double.random(in: 0.5...5.0),
                hasNews: Bool.random(),
                rank: $0,
                highlights: [],
                highlightTimestamp: nil
            )
        }

        onUpdate?()
    }

    // MARK: - Start Mock Socket
    func startMockSocket() {
        mockTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.generateMockUpdate()
        }
    }

    // MARK: - Generate Fake Updates
    private func generateMockUpdate() {
        var newData: [ScannerItem] = []

        for item in items {

            var updated = item

            // Simulate movement
            let change = Double.random(in: -2...5)
            updated.pctUp = max(0, item.pctUp + change)

            updated.lastPrice += Double.random(in: -0.5...0.8)

            // IMPORTANT: keep previous high for comparison
            let previousHigh = updated.high
            updated.high = max(updated.high, updated.lastPrice)

            updated.volume += Int.random(in: 1000...5000)

            // Random news flip
            if Int.random(in: 0...10) > 8 {
                updated.hasNews.toggle()
            }

            newData.append(updated)
        }

        // Shuffle ranking occasionally
        if Bool.random() {
            newData.shuffle()
            for i in 0..<newData.count {
                newData[i].rank = i + 1
            }
        }

        updateFromSocket(newData)
    }

    // MARK: - Socket Update Entry
    func updateFromSocket(_ newData: [ScannerItem]) {

        var updated: [ScannerItem] = []

        for newItem in newData {

            if let old = items.first(where: { $0.symbol == newItem.symbol }) {

                var item = newItem

                // 🔥 RESET highlights every cycle
                item.highlights = []

                // 🔥 MULTI-HIGHLIGHT LOGIC (NO else-if)

                if newItem.rank < old.rank - 1 {
                    item.highlights.insert(.rankSurge)
                }

                // Correct HOD detection
                if newItem.lastPrice > old.high + 0.2 {
                    item.highlights.insert(.hod)
                }

                if newItem.pctUp > old.pctUp + 2 { // threshold
                    item.highlights.insert(.pctSurge)
                }

                // Handle timestamp
                if !item.highlights.isEmpty {
                    item.highlightTimestamp = Date()
                } else {
                    // Preserve previous highlight until decay
                    item.highlights = old.highlights
                    item.highlightTimestamp = old.highlightTimestamp
                }

                updated.append(item)

            } else {
                updated.append(newItem)
            }
        }

        items = updated
        onUpdate?()
    }

    // MARK: - Highlight Timer
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.decayHighlights()
        }
    }

    private func decayHighlights() {
        let now = Date()
        var changed = false

        for i in 0..<items.count {
            if let ts = items[i].highlightTimestamp,
               now.timeIntervalSince(ts) > highlightDuration {

                items[i].highlights.removeAll()
                items[i].highlightTimestamp = nil
                changed = true
            }
        }

        if changed {
            onUpdate?()
        }
    }
}
