//
//  CalmScoreDiagnosticsView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 20/11/25.
//


//
//  CalmScoreDiagnosticsView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 20/11/25.
//

import SwiftUI
import Foundation

struct CalmScoreDiagnosticsView: View {
    @State private var entries: [CalmScoreDiagnosticEntry] = []
    @State private var groups: [DayGroup] = []
    @Environment(\.dismiss) private var dismiss

    init(limit: Int = 15, newestFirst: Bool = true) {

        // Step 1 — Load entries
        let snapshot = CalmScoreDiagnosticsStore.shared.lastEntries

        // Step 2 — Sort (keep it small for compiler)
        let sorted: [CalmScoreDiagnosticEntry]
        if newestFirst {
            sorted = snapshot.sorted { $0.timestamp > $1.timestamp }
        } else {
            sorted = snapshot.sorted { $0.timestamp < $1.timestamp }
        }

        // Step 3 — Limit
        let limited = Array(sorted.prefix(limit))

        // Step 4 — Build groups separately
        let computedGroups = CalmScoreDiagnosticsView.buildGroups(from: limited)

        // Assign final state
        _entries = State(initialValue: limited)
        _groups  = State(initialValue: computedGroups)
    }

    var body: some View {
        NavigationStack {
            List {
                latestSection
                inputsSection
                contributionsSection
                summarySection
                historySection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("CalmScore Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear { refreshEntries() }
        .onChange(of: entries) { _ in
            groups = Self.buildGroups(from: entries)
        }
    }

    private var latestSection: some View {
        Group {
            if let latest = entries.first {
                Section("Latest CalmScore") {
                    LatestCard(entry: latest, previous: entries.dropFirst().first)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var inputsSection: some View {
        Group {
            if let latest = entries.first {
                Section("Current Inputs") {
                    InputsCard(entry: latest)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var contributionsSection: some View {
        Group {
            if let latest = entries.first {
                Section("Metric Contributions") {
                    ContributionsCard(entry: latest)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var summarySection: some View {
        Group {
            if let latest = entries.first {
                Section("Summary") {
                    Text(latest.summary)
                        .font(.callout)
                        .foregroundColor(.primary)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    private var historySection: some View {
        Section("History") {
            ForEach(groups.indices, id: \.self) { gi in
                let group = groups[gi]
                if !group.items.isEmpty {
                    Section(group.day) {
                        ForEach(group.items.indices, id: \.self) { idx in
                            HistoryRow(entry: group.items[idx])
                        }
                    }
                }
            }
        }
    }

    private func refreshEntries() {
        let snapshot = CalmScoreDiagnosticsStore.shared.lastEntries
        let sorted = snapshot.sorted { $0.timestamp > $1.timestamp }
        let limited = Array(sorted.prefix(entries.count))
        self.entries = limited
        self.groups = Self.buildGroups(from: limited)
    }


    // MARK: - Grouping

    private struct DayGroup: Identifiable {
        let id = UUID()
        let day: String
        let items: [CalmScoreDiagnosticEntry]
    }

    private static let dayDF: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f
    }()

    private static func buildGroups(from rows: [CalmScoreDiagnosticEntry]) -> [DayGroup] {
        let dayFor: (CalmScoreDiagnosticEntry) -> String = { row in
            dayDF.string(from: row.timestamp)
        }

        let dict: [String: [CalmScoreDiagnosticEntry]] = Dictionary(grouping: rows, by: dayFor)

        var seen = Set<String>()
        var orderedDays: [String] = []
        orderedDays.reserveCapacity(rows.count)
        for r in rows {
            let d = dayFor(r)
            if seen.insert(d).inserted { orderedDays.append(d) }
        }

        return orderedDays.map { d in
            DayGroup(day: d, items: dict[d] ?? [])
        }
    }
}

// MARK: - Latest card

private struct LatestCard: View {
    let entry: CalmScoreDiagnosticEntry
    let previous: CalmScoreDiagnosticEntry?

    private static let timeDF: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private var timeText: String {
        Self.timeDF.string(from: entry.timestamp)
    }

    private var deltaText: String {
        guard let prev = previous else { return "First sample" }
        let delta = entry.finalScore - prev.finalScore
        if abs(delta) < 0.5 { return "No major change vs last" }
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(delta.rounded(toPlaces: 1)) vs last"
    }

    private var trendColor: Color {
        guard let prev = previous else { return .secondary }
        let delta = entry.finalScore - prev.finalScore
        if delta > 0.5 { return .green }
        if delta < -0.5 { return .red }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(Int(entry.finalScore).description)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()

                VStack(alignment: .leading, spacing: 4) {
                    Text("CalmScore")
                        .font(.headline)
                    Text(timeText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(deltaText)
                    .font(.caption)
                    .foregroundColor(trendColor)
            }

            HStack(spacing: 8) {
                Tag(text: "HRV", color: .blue, z: entry.zHRV)
                Tag(text: "HR", color: .orange, z: entry.zHR)
                Tag(text: "RHR", color: .purple, z: entry.zRHR)
                Tag(text: "Sleep", color: .teal, z: entry.zSleep)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(.secondarySystemBackground)))
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }

    private struct Tag: View {
        let text: String
        let color: Color
        let z: Double?

        var body: some View {
            HStack(spacing: 4) {
                Text(text)
                if let z {
                    Text(z.rounded(toPlaces: 2).description)
                }
            }
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Inputs card

private struct InputsCard: View {
    let entry: CalmScoreDiagnosticEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MetricRow(
                title: "Heart Rate",
                value: entry.inputs.heartRate,
                unit: "bpm",
                z: entry.zHR,
                accent: .orange
            )
            MetricRow(
                title: "Resting HR",
                value: entry.inputs.restingHeartRate,
                unit: "bpm",
                z: entry.zRHR,
                accent: .purple
            )
            MetricRow(
                title: "HRV (RMSSD)",
                value: entry.inputs.hrvInRmssd,
                unit: "ms",
                z: entry.zHRV,
                accent: .blue
            )
            MetricRow(
                title: "HRV (SDNN)",
                value: entry.inputs.hrvInSdnn,
                unit: "ms",
                z: nil,
                accent: .blue.opacity(0.7)
            )
            MetricRow(
                title: "Sleep",
                value: entry.inputs.sleepDurationInHours,
                unit: "h",
                z: entry.zSleep,
                accent: .teal
            )
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(.secondarySystemBackground)))
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }

    private struct MetricRow: View {
        let title: String
        let value: Double?
        let unit: String
        let z: Double?
        let accent: Color

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                    if let z {
                        Text("Z-score \(z.rounded(toPlaces: 2))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let value {
                    Text("\(value.rounded(toPlaces: 2)) \(unit)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(accent)
                        .monospacedDigit()
                } else {
                    Text("—")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Contributions card

private struct ContributionsCard: View {
    let entry: CalmScoreDiagnosticEntry

    private var totalAbs: Double {
        let vals = [
            abs(entry.contribHRV),
            abs(entry.contribHR),
            abs(entry.contribRHR),
            abs(entry.contribSleep)
        ]
        return max(vals.max() ?? 1.0, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ContributionRow(
                label: "HRV",
                value: entry.contribHRV,
                color: .blue,
                totalAbs: totalAbs
            )
            ContributionRow(
                label: "Heart Rate",
                value: entry.contribHR,
                color: .orange,
                totalAbs: totalAbs
            )
            ContributionRow(
                label: "Resting HR",
                value: entry.contribRHR,
                color: .purple,
                totalAbs: totalAbs
            )
            ContributionRow(
                label: "Sleep",
                value: entry.contribSleep,
                color: .teal,
                totalAbs: totalAbs
            )
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(.secondarySystemBackground)))
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }

    private struct ContributionRow: View {
        let label: String
        let value: Double
        let color: Color
        let totalAbs: Double

        private var signText: String {
            value >= 0 ? "+" : "−"
        }

        private var magnitude: Double {
            min(abs(value) / totalAbs, 1.0)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.subheadline)
                    Spacer()
                    Text("\(signText)\(abs(value).rounded(toPlaces: 1)) pts")
                        .font(.caption)
                        .foregroundColor(value >= 0 ? .green : .red)
                }

                GeometryReader { geo in
                    ZStack(alignment: value >= 0 ? .leading : .trailing) {
                        Capsule()
                            .fill(Color(.systemFill))
                        Capsule()
                            .fill(value >= 0 ? color : Color.red)
                            .frame(width: geo.size.width * magnitude)
                    }
                }
                .frame(height: 8)
            }
        }
    }
}

// MARK: - History row

private struct HistoryRow: View {
    let entry: CalmScoreDiagnosticEntry

    private static let timeDF: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private var timeText: String {
        Self.timeDF.string(from: entry.timestamp)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeText)
                    .font(.callout)
                    .fontWeight(.semibold)
                Text(entry.summary)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Text(Int(entry.finalScore).description)
                .font(.headline)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helpers

fileprivate extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}
