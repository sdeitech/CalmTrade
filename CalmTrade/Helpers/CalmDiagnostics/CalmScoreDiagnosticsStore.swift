//
//  CalmScoreDiagnosticsStore.swift
//  CalmTrade
//
//  Created by Anas Parekh on 20/11/25.
//


final class CalmScoreDiagnosticsStore {
    static let shared = CalmScoreDiagnosticsStore()
    private init() {}

    private(set) var lastEntries: [CalmScoreDiagnosticEntry] = []

    func add(_ entry: CalmScoreDiagnosticEntry) {
        lastEntries.append(entry)
        if lastEntries.count > 15 {
            lastEntries.removeFirst()
        }
    }
}
