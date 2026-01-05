//
//  SleepLogView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 23/10/25.
//

import SwiftUI

struct SleepLogView: View {
    @State private var rows: [SleepLogEntry] = []
    @State private var groups: [DayGroup] = []          // <- precomputed, not computed in body
    @Environment(\.dismiss) private var dismiss

    init(limit: Int? = nil, newestFirst: Bool = true) {
        let fetched = SleepHistoryStore.shared.fetchAllSessions(limit: limit,
                                                                before: Date(),
                                                                ascending: !newestFirst)
        _rows = State(initialValue: fetched)
        _groups = State(initialValue: Self.buildGroups(from: fetched))
    }

    // Rebuild groups whenever rows change (if you ever mutate rows later)
    var body: some View {
        NavigationStack {
            List {
                // Iterate by indices to simplify type-checking
                ForEach(groups.indices, id: \.self) { gi in
                    let group = groups[gi]
                    Section {
                        ForEach(group.items.indices, id: \.self) { ri in
                            SleepRowView(entry: group.items[ri])
                        }
                    } header: {
                        Text(group.day)
                    }
                }
            }
            .navigationTitle("Sleep Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onChange(of: rows) { newRows in
            groups = Self.buildGroups(from: newRows)
        }
    }

    // MARK: - Models / helpers

    private struct DayGroup: Identifiable {
        let id = UUID()
        let day: String
        let items: [SleepLogEntry]
    }

    private static let dayDF: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f
    }()

    private static func buildGroups(from rows: [SleepLogEntry]) -> [DayGroup] {
        // Group by day string
        let dayFor: (SleepLogEntry) -> String = { row in
            dayDF.string(from: row.sessionStart)
        }
        let dict: [String : [SleepLogEntry]] = Dictionary(grouping: rows, by: dayFor)

        // Keep days in the display order of rows
        var seen = Set<String>()
        var orderedDays: [String] = []
        orderedDays.reserveCapacity(rows.count)
        for r in rows {
            let d = dayFor(r)
            if seen.insert(d).inserted { orderedDays.append(d) }
        }

        // Map to groups
        return orderedDays.map { d in
            DayGroup(day: d, items: dict[d] ?? [])
        }
    }
}

// MARK: - Tiny pill badge for source
private struct SourceBadge: View {
    let text: String
    let tint: Color
    var body: some View {
        Text(text)
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(tint.opacity(0.18))
            .foregroundColor(tint)          // simpler than foregroundStyle
            .clipShape(Capsule())
    }
}

// MARK: - Row (minimal nested interpolation)
private struct SleepRowView: View {
    let entry: SleepLogEntry

    private static let timeDF: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    private var startText: String { Self.timeDF.string(from: entry.sessionStart) }
    private var endText:   String { Self.timeDF.string(from: entry.sessionEnd) }
    private var totalText: String { "Total " + fmt(entry.totalSeconds) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left: time range + source
            VStack(alignment: .leading, spacing: 4) {
                Text(startText + " → " + endText)
                    .font(.callout)
                    .fontWeight(.semibold)

                HStack(spacing: 6) {
                    SourceBadge(text: entry.source.displayName,
                                tint: entry.source == .ct360 ? .blue : .green)
                    Text(totalText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 12)

            // Right: per-stage summary
            VStack(alignment: .trailing, spacing: 2) {
                StageLine(label: "REM",  seconds: entry.remSeconds)
                StageLine(label: "Core", seconds: entry.coreSeconds)
                StageLine(label: "Deep", seconds: entry.deepSeconds)
                StageLine(label: "Awake", seconds: entry.awakeSeconds)
            }
            .monospacedDigit()
        }
        .padding(.vertical, 6)
    }

    private struct StageLine: View {
        let label: String
        let seconds: TimeInterval
        var body: some View {
            HStack(spacing: 6) {
                Text(label).font(.caption).foregroundColor(.secondary)
                Text(fmt(seconds)).font(.caption).fontWeight(.semibold)
            }
        }
    }

    private static func fmt(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) / 60) % 60
        return h > 0 ? "\(h)h \(String(format: "%02d", m))m" : "\(m)m"
    }
    private func fmt(_ seconds: TimeInterval) -> String { Self.fmt(seconds) }
}
