import Foundation

final class PolarDailySyncCoordinator {
    static let shared = PolarDailySyncCoordinator()
    private var timer: Timer?

    func startWhileConnected(deviceId: String) {
        stop()
        fetchTodayAndYesterday(deviceId: deviceId)        // backfill immediately
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.fetchToday(deviceId: deviceId)
        }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func fetchToday(deviceId: String) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        PolarManager.shared.fetchPolarActivity(deviceId: deviceId, date: today) { minutes in
            PolarManager.shared.submitPolar360MinuteSteps(minutes)
        }
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
}
