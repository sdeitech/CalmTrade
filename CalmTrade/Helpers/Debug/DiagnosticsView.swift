//
//  DiagnosticsView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 16/09/25.
//


// DiagnosticsView.swift
import SwiftUI
import HealthKit

struct DiagnosticsView: View {
    @State private var lines: [String] = DebugLog.shared.snapshot()
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                // Quick status chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("Source: \(DeviceManager.shared.currentSource)")
                        chip("HK HRV write: \(HealthKitService.shared.authorizationStatusForWriteHRV)")
                        chip("Live RMSSD TTL: \(DeviceManager.shared.liveTTL)s")
                    }.padding(.horizontal)
                }

                Divider()

                // Live log
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(lines.indices, id: \.self) { i in
                            Text(lines[i]).font(.caption2.monospaced())
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.padding(.horizontal)
                }
            }
            .navigationTitle("Live Diagnostics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        if let url = DebugLog.shared.exportToTempFile() {
                            DebugLog.shared.log("Exported logs to \(url.lastPathComponent)")
                        }
                    }
                }
            }
        }
        .onAppear { DebugLog.shared.onChange = { self.lines = DebugLog.shared.snapshot() } }
        .onDisappear { DebugLog.shared.onChange = nil }
        .onReceive(timer) { _ in lines = DebugLog.shared.snapshot() }
    }

    private func chip(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.secondary.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Tiny HUD overlay (optional)
struct DiagnosticsHUD: View {
    @State private var lastTwo: [String] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Diagnostics").bold().font(.caption)
            ForEach(lastTwo, id: \.self) { s in
                Text(s).font(.caption2).lineLimit(1).truncationMode(.middle)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .onAppear {
            DebugLog.shared.onChange = {
                let snap = DebugLog.shared.snapshot()
                lastTwo = Array(snap.suffix(2))
            }
        }
        .onDisappear { DebugLog.shared.onChange = nil }
    }
}

// MARK: - HealthKitService helper (auth status string)
extension HealthKitService {
    var authorizationStatusForWriteHRV: String {
        let status = healthStore.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!)
        switch status {
        case .notDetermined: return "unknown"
        case .sharingDenied: return "denied"
        case .sharingAuthorized: return "authorized"
        @unknown default: return "unknown"
        }
    }
}
