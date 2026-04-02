import Foundation

final class PolarDailySyncCoordinator {
    static let shared = PolarDailySyncCoordinator()
    private var syncTimer: Timer?
    private var isSyncInFlight = false

    func startWhileConnected(deviceId: String) {
        stop()
        DispatchQueue.global(qos: .utility).async {
            self.fetchTodayAndYesterday(deviceId: deviceId)        // backfill immediately
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
            self.syncToday(deviceId: deviceId)
        }

        syncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .utility).async {
                self?.syncToday(deviceId: deviceId)
            }
        }

        if let t = syncTimer { RunLoop.main.add(t, forMode: .common) }
    }

    func stop() {
        syncTimer?.invalidate()
        syncTimer = nil
        isSyncInFlight = false
    }

    func fetchTodayAndYesterday(deviceId: String) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        PolarManager.shared.fetchPolarActivity(deviceId: deviceId, date: yesterday) { minutes in
            PolarManager.shared.submitPolar360MinuteSteps(minutes)
        }
        PolarManager.shared.fetchPolarActivity(deviceId: deviceId, date: today) { minutes in
            PolarManager.shared.submitPolar360MinuteSteps(minutes)
        }
    }

    private func syncToday(deviceId: String) {
        guard !isSyncInFlight else { return }
        isSyncInFlight = true

        PolarManager.shared.refreshPolarTodayActivity(deviceId: deviceId) { [weak self] total, minutes in
            guard let self else { return }

            if let total {
                PolarManager.shared.submitPolar360LiveStepsTotal(total)
            }
            PolarManager.shared.submitPolar360MinuteSteps(minutes)

            self.isSyncInFlight = false
        }
    }
}
