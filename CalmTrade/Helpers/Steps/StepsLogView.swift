//
//  StepsLogView.swift
//  CalmTrade
//
//  Sleep-log style Steps Log with stable IDs, off-main loading, and paging.
//

import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class StepsLogViewModel: ObservableObject {
    @Published var groups: [DayGroup] = []
    @Published var hasMore: Bool = false

    private let dayDF: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f
    }()

    struct DayGroup: Identifiable, Equatable {
        var id: String { day }          // stable identity by day string
        let day: String
        var items: [StepLogEntry]
    }

    // Paging state
    private var currentLimit: Int
    private var daysBack: Int
    private var newestFirst: Bool

    // Debounce reloads when repo posts updates
    private var cancellables = Set<AnyCancellable>()

    init(limit: Int, newestFirst: Bool, daysBack: Int) {
        self.currentLimit = max(100, limit)  // sensible floor
        self.daysBack = daysBack
        self.newestFirst = newestFirst

        // Listen for metric changes (e.g., Polar sync) and refresh
        NotificationCenter.default.publisher(for: .ctMetricUpdated)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
    }

    func reload() {
        let limit = currentLimit
        let oldestFirst = !newestFirst

        Task.detached(priority: .userInitiated) {
            let rows = await StepsHistoryStore.shared.fetchAllSteps(
                limit: limit + 1,                // pull one extra to know if there's more
                before: Date(),
                ascending: oldestFirst,
                daysBack: self.daysBack
            )

            let hasMore = rows.count > limit
            let trimmed = hasMore ? Array(rows.prefix(limit)) : rows

            // Build groups off-main
            let grouped = await Self.buildGroups(from: trimmed, dayDF: self.dayDF)

            await MainActor.run {
                self.hasMore = hasMore
                self.groups = grouped
            }
        }
    }

    func loadMore() {
        currentLimit = Int(Double(currentLimit) * 1.7).clamped(min: currentLimit + 200, max: 10000)
        reload()
    }

    private static func buildGroups(from rows: [StepLogEntry], dayDF: DateFormatter) -> [DayGroup] {
        // group by day label
        let dayFor: (StepLogEntry) -> String = { row in dayDF.string(from: row.timestamp) }
        let dict = Dictionary(grouping: rows, by: dayFor)

        // keep order by appearance
        var seen = Set<String>()
        var ordered: [String] = []
        ordered.reserveCapacity(dict.count)

        for r in rows {
            let d = dayFor(r)
            if seen.insert(d).inserted { ordered.append(d) }
        }

        return ordered.compactMap { d in
            let items = (dict[d] ?? [])
            return items.isEmpty ? nil : DayGroup(day: d, items: items)
        }
    }
}

private extension Comparable {
    func clamped(min: Self, max: Self) -> Self { Swift.max(min, Swift.min(max, self)) }
}

// MARK: - View

struct StepsLogView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: StepsLogViewModel

    init(limit: Int? = 500, newestFirst: Bool = true, daysBack: Int = 14) {
        _vm = StateObject(wrappedValue: StepsLogViewModel(limit: limit ?? 500,
                                                          newestFirst: newestFirst,
                                                          daysBack: daysBack))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.groups) { g in
                    Section {
                        ForEach(g.items) { entry in
                            StepRowView(entry: entry)
                        }
                    } header: {
                        Text(g.day)
                    }
                }

                if vm.hasMore {
                    HStack {
                        Spacer()
                        Button {
                            vm.loadMore()
                        } label: {
                            ProgressView() // lightweight spinner look
                                .progressViewStyle(.circular)
                                .padding(.trailing, 8)
                            Text("Load older")
                        }
                        Spacer()
                    }
                    .listRowInsets(EdgeInsets())
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Steps Log")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sync") {
                        if let dev = PolarManager.shared.connectedDevice {
                            PolarDailySyncCoordinator.shared.startWhileConnected(deviceId: dev.id)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { vm.reload() } // initial load
    }
}

// MARK: - Row

private struct StepRowView: View {
    let entry: StepLogEntry

    private static let timeDF: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm:ss a"; return f
    }()

    private var timeText: String { Self.timeDF.string(from: entry.timestamp) }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(timeText)
                    .font(.callout).fontWeight(.semibold)

                HStack(spacing: 8) {
                    SourceBadge(text: label(for: entry.source), tint: tint(for: entry.source))
                    Text("\(entry.steps) steps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func label(for src: CTMetricSource) -> String {
        switch src {
        case .polar360: return "Polar 360"
        case .polarH10: return "Polar H10"
        case .appleHealth: return "Apple Health"
        default: return src.rawValue
        }
    }
    private func tint(for src: CTMetricSource) -> Color {
        switch src {
        case .polar360: return .blue
        case .polarH10: return .green
        case .appleHealth: return .orange
        default: return .gray
        }
    }
}

// MARK: - Reusable pill

private struct SourceBadge: View {
    let text: String
    let tint: Color
    var body: some View {
        Text(text)
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(tint.opacity(0.18))
            .foregroundColor(tint)
            .clipShape(Capsule())
    }
}
