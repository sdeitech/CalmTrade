//
//  CalmScoreLogView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 23/09/25.
//

import SwiftUI
import CoreData

struct CalmScoreLogView: View {
    @FetchRequest private var results: FetchedResults<CalmScoreSample>
    @Environment(\.dismiss) private var dismiss

    init(limit: Int? = nil, newestFirst: Bool = true) {
        let req: NSFetchRequest<CalmScoreSample> = CalmScoreSample.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: !newestFirst)]
        if let l = limit { req.fetchLimit = l }
        _results = FetchRequest(fetchRequest: req)
    }

    private static let dayDF: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d, yyyy"; return f
    }()
    private static let timeDF: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm:ss a"; return f
    }()

    var body: some View {
        NavigationView {
            Group {
                if results.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No CalmScore records found.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .systemGroupedBackground))
                } else {
                    List {
                        ForEach(groupedDays, id: \.day) { group in
                            Section(header: Text(group.day)) {
                                ForEach(group.items, id: \.objectID) { row in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(Self.timeDF.string(from: row.timestamp ?? Date()))
                                                .font(.callout).fontWeight(.semibold)
                                            if let src = row.source, !src.isEmpty {
                                                Text("Source: \(src)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            if let uid = row.userId, !uid.isEmpty {
                                                Text("User: \(uid)")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        Spacer(minLength: 12)
                                        VStack(alignment: .trailing) {
                                            Text("\(Int(row.value.rounded()))")
                                                .font(.title3)
                                                .monospacedDigit()
                                                .fontWeight(.bold)
                                            Text("pts")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("CalmScore Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        CalmScoreLogger.shared.dumpAll()
                    } label: {
                        Label("Dump to Console", systemImage: "terminal")
                    }
                }
            }
        }
    }

    private var groupedDays: [(day: String, items: [CalmScoreSample])] {
        let dict = Dictionary(grouping: results) { row in
            Self.dayDF.string(from: row.timestamp ?? Date())
        }
        return dict.keys.sorted(by: >).map { day in
            (day, dict[day]!.sorted(by: { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }))
        }
    }
}

final class CalmScoreLogger {
    static let shared = CalmScoreLogger()
    private let context = CoreDataStack.shared.viewContext
    private var observer: NSObjectProtocol?

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { note in
            if let objs = note.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> {
                let scoreRows = objs.compactMap { $0 as? CalmScoreSample }
                guard !scoreRows.isEmpty else { return }
                for row in scoreRows {
                    let ts = row.timestamp ?? Date()
                    let val = row.value
                    let src = row.source ?? "?"
                    print("💾 [CalmScoreLogger] Saved: \(Int(val)) at \(ts) [\(src)] userId=\(row.userId ?? "_")]")
                }
            }
        }
    }

    func dumpAll() {
        let req: NSFetchRequest<CalmScoreSample> = CalmScoreSample.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        if let rows = try? context.fetch(req) {
            print("📜 [CalmScoreLogger] \(rows.count) rows in CalmScoreSample")
            for r in rows.prefix(20) {
                let ts = r.timestamp ?? Date()
                let src = r.source ?? "?"
                let uid = r.userId ?? "_"
                print("  • \(ts): \(Int(r.value)) pts [\(src)] user=\(uid)")
            }
        } else {
            print("⚠️ [CalmScoreLogger] Fetch failed.")
        }
    }
}
