//
//  BiometricsViewController.swift
//  CalmTrade
//
//  Hosts SwiftUI CalmScoreBarTile + Sleep Score tile (attributed "88/100").
//

import UIKit
import SwiftUI
import Combine

final class BiometricsViewController: UIViewController {

    // MARK: - Outlets
    /// SwiftUI CalmScore gauge container (existing)
    @IBOutlet weak var calmScoreGauge: UIView!

    // Sleep Score tile
    @IBOutlet weak var sleepScoreContainer: UIView!
    @IBOutlet weak var sleepScoreLabel: UILabel!      // shows "88/100" as attributed text
    @IBOutlet weak var sleepScoreDateLabel: UILabel!  // "Today", "Yesterday", or formatted date

    @IBOutlet weak var lblHeartRateAverage: UILabel!
    @IBOutlet weak var lblHeartRateLatest: UILabel!

    // --- HRV split: RMSSD + SDNN (replace old lblHrv* outlets) ---
    @IBOutlet weak var lblRmssdAverage: UILabel!
    @IBOutlet weak var lblRmssdLatest: UILabel!
    @IBOutlet weak var lblRmssdTimestamp: UILabel!

    @IBOutlet weak var lblSdnnAverage: UILabel!
    @IBOutlet weak var lblSdnnLatest: UILabel!
//    @IBOutlet weak var lblSdnnTimestamp: UILabel!

    @IBOutlet weak var lblRestingHrAverage: UILabel!
    @IBOutlet weak var lblRestingHrLatest: UILabel!
    @IBOutlet weak var lblRestingHrTimestamp: UILabel!

    // Existing sleep duration + steps tiles
    @IBOutlet weak var lblSleepTotal: UILabel!
    @IBOutlet weak var lblSleepDate: UILabel!

    @IBOutlet weak var lblStepsAverage: UILabel!
    @IBOutlet weak var lblStepsToday: UILabel!
    @IBOutlet weak var lblStepsDate: UILabel!

    // MARK: - ViewModel
    private let viewModel = BiometricsViewModel()
    private var bag = Set<AnyCancellable>()

    // MARK: - SwiftUI hosting
    private var calmScoreTileController: UIHostingController<CalmScoreBarTile>?

    // MARK: - Formatters
    private lazy var dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE d MMM yyyy" // “Thu 6 Jun 2025”
        return df
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSwiftUIGauge()
        setupSleepScoreTileAccessibility()
        bindViewModel()

        // Add notification observers for app lifecycle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        viewModel.start()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.startLiveUpdates()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopLiveUpdates()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        let vc = UIHostingController(rootView: DiagnosticsView())
        present(vc, animated: true)
    }

    // MARK: - SwiftUI Gauge embedding
    private func setupSwiftUIGauge() {
        // Initial empty props; ViewModel will push real values via onPropsUpdate
        let initialProps = CalmScoreTileProps(
            score: 0,
            lastUpdate: Date(),
            deviceSource: .appleHK,
            isStreaming: false,
            trend: TrendData(hrvMs: 0, hrvIsUp: true, hrBpm: 0, hrIsDown: true, sleepHours: 0, sleepIsUp: true)
        )

        let onConnectTap: () -> Void = { [weak self] in
            guard let self = self else { return }
            let vc = UIStoryboard(name: Constants.Storyboard.Devices, bundle: nil)
                .instantiateViewController(withIdentifier: "PolarConnectionViewController") as! PolarConnectionViewController
            self.navigationController?.pushViewController(vc, animated: true)
        }

        let onTileTap: () -> Void = { [weak self] in
            guard let self = self else { return }
            let details = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil)
                .instantiateViewController(withIdentifier: "CalmScoreDetailsViewController") as! CalmScoreDetailsViewController
            self.navigationController?.pushViewController(details, transitionType: .reveal)
        }

        let swiftUIView = CalmScoreBarTile(
            props: initialProps,
            onConnectTap: onConnectTap,
            onTileTap: onTileTap
        )

        let host = UIHostingController(rootView: swiftUIView)
        host.view.backgroundColor = .clear

        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        calmScoreGauge.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: calmScoreGauge.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: calmScoreGauge.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: calmScoreGauge.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: calmScoreGauge.bottomAnchor)
        ])
        host.didMove(toParent: self)
        calmScoreTileController = host
    }

    // MARK: - Sleep Score tile (accessibility & defaults)
    private func setupSleepScoreTileAccessibility() {
        sleepScoreLabel.adjustsFontForContentSizeCategory = true
        sleepScoreDateLabel.adjustsFontForContentSizeCategory = true

        sleepScoreLabel.attributedText = placeholderSleepScore()
        sleepScoreDateLabel.text = "No data"
        sleepScoreContainer.alpha = 0.7
    }

    // MARK: - Bindings
    private func bindViewModel() {
        // If you want label-by-label Combine bindings, add here

        // SwiftUI gauge props
        viewModel.onPropsUpdate = { [weak self] props in
            let onConnectTap: () -> Void = { [weak self] in
                guard let self = self else { return }
                let vc = UIStoryboard(name: Constants.Storyboard.Devices, bundle: nil)
                    .instantiateViewController(withIdentifier: "PolarConnectionViewController") as! PolarConnectionViewController
                self.navigationController?.pushViewController(vc, animated: true)
            }

            let onTileTap: () -> Void = { [weak self] in
                guard let self = self else { return }
                let details = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil)
                    .instantiateViewController(withIdentifier: "CalmScoreDetailsViewController") as! CalmScoreDetailsViewController
                self.navigationController?.pushViewController(details, transitionType: .reveal)
            }

            self?.calmScoreTileController?.rootView = CalmScoreBarTile(
                props: props,
                onConnectTap: onConnectTap,
                onTileTap: onTileTap
            )
        }

        // Legacy labels
        viewModel.onDataUpdated = { [weak self] data in
            self?.updateUI(with: data)
        }

        // Sleep Score tile
        viewModel.onSleepScoreDidUpdate = { [weak self] tile in
            guard let self = self else { return }
            DispatchQueue.main.async { self.renderSleepScore(tile) }
        }
    }

    // MARK: - UI update for legacy labels
    private func updateUI(with data: BiometricData) {
        lblHeartRateAverage.text = data.heartRateAverage
        lblHeartRateLatest.text = data.heartRateLatest

        // HRV split
        lblRmssdAverage.text = data.rmssdAverage
        lblRmssdLatest.text = data.rmssdLatest
        lblRmssdTimestamp.text = data.rmssdTimestamp

        // Highlight stale RMSSD data
        if data.isRmssdDataStale {
            lblRmssdLatest.textColor = .systemRed
            lblRmssdAverage.textColor = .systemRed
            lblRmssdTimestamp.text = data.rmssdTimestamp
        } else {
            lblRmssdLatest.textColor = .label
            lblRmssdAverage.textColor = .label
        }

        lblSdnnAverage.text = data.sdnnAverage
        lblSdnnLatest.text = data.sdnnLatest
//        lblSdnnTimestamp.text = data.sdnnTimestamp

        // Highlight stale SDNN data
        if data.isSdnnDataStale {
            lblSdnnLatest.textColor = .systemRed
            lblSdnnAverage.textColor = .systemRed
        } else {
            lblSdnnLatest.textColor = .label
            lblSdnnAverage.textColor = .label
        }

        lblRestingHrAverage.text = data.restingHeartRateAverage
        lblRestingHrLatest.text = data.restingHeartRateLatest
        lblRestingHrTimestamp.text = data.restingHeartRateTimestamp

        lblSleepTotal.text = data.sleepTotal
        lblSleepDate.text = data.sleepDate

        lblStepsAverage.text = data.stepsWeeklyAverage
        lblStepsToday.text = data.stepsToday
        lblStepsDate.text = data.stepsDate

        logBiometricsSteps(data: data)
    }

    private func logBiometricsSteps(data: BiometricData) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = Date()
        let repo = CTMetricsRepository.shared

        let mergedToday = Int(StepEngine.stepsTotal(from: start, to: end).rounded())
        let polarToday = repo.series(kind: .steps, from: start, to: end, source: .polar360)
            .reduce(0) { $0 + Int($1.value.rounded()) }
        let appleToday = repo.series(kind: .steps, from: start, to: end, source: .appleHealth)
            .reduce(0) { $0 + Int($1.value.rounded()) }

        print("=== Biometrics Steps Tile ===")
        print("Displayed Today: \(data.stepsToday)")
        print("Displayed Weekly Avg: \(data.stepsWeeklyAverage)")
        print("Displayed Date: \(data.stepsDate)")
        print("Window: \(start) -> \(end)")
        print("Merged Today (StepEngine): \(mergedToday)")
        print("Polar Raw Today: \(polarToday)")
        print("Apple Raw Today: \(appleToday)")
        print("=============================")
    }

    // MARK: - Sleep Score rendering (single attributed label)
    private func renderSleepScore(_ tile: SleepScoreTile?) {
        guard let tile = tile else {
            sleepScoreLabel.attributedText = placeholderSleepScore()
            sleepScoreDateLabel.text = "No data"
            sleepScoreContainer.alpha = 0.7
            return
        }

        sleepScoreLabel.attributedText = makeSleepScoreText(score: tile.score, max: 100)

        let cal = Calendar.current
        if cal.isDateInToday(tile.date) {
            sleepScoreDateLabel.text = "Today"
        } else if cal.isDateInYesterday(tile.date) {
            sleepScoreDateLabel.text = "Yesterday"
        } else {
            sleepScoreDateLabel.text = dayFormatter.string(from: tile.date)
        }

        sleepScoreContainer.alpha = 1.0
    }

    private func makeSleepScoreText(score: Int, max: Int = 100) -> NSAttributedString {
        let numberFont  = UIFont.systemFont(ofSize: 44, weight: .heavy)
        let suffixFont  = UIFont.systemFont(ofSize: 24, weight: .semibold)

        let numberScaled = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: numberFont)
        let suffixScaled = UIFontMetrics(forTextStyle: .title2).scaledFont(for: suffixFont)

        let numberColor  = UIColor.white
        let suffixColor  = UIColor(white: 1.0, alpha: 0.5)

        let s = NSMutableAttributedString(
            string: "\(score)",
            attributes: [.font: numberScaled, .foregroundColor: numberColor]
        )
        let suffix = NSAttributedString(
            string: "/\(max)",
            attributes: [.font: suffixScaled, .foregroundColor: suffixColor, .baselineOffset: 4]
        )
        s.append(suffix)
        return s
    }

    private func placeholderSleepScore() -> NSAttributedString {
        NSAttributedString(
            string: "—/100",
            attributes: [
                .font: UIFontMetrics(forTextStyle: .largeTitle)
                    .scaledFont(for: UIFont.systemFont(ofSize: 36, weight: .bold)),
                .foregroundColor: UIColor(white: 1.0, alpha: 0.5)
            ]
        )
    }

    @objc private func appWillEnterForeground() {
        viewModel.handleAppWillEnterForeground()
    }

    @objc private func appDidBecomeActive() {
        viewModel.handleAppDidBecomeActive()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        viewModel.stop()
    }

    // MARK: - Actions
    @IBAction func btnRMSSDTapped(_ sender: Any) {
        let vc = UIStoryboard(name: Constants.Storyboard.Biometrics, bundle: nil)
            .instantiateViewController(withIdentifier: "HRVDetailViewController") as! HRVDetailViewController
        vc.metric = .rmssd
        navigationController?.pushViewController(vc, transitionType: .fade)
    }

    @IBAction func btnSDNNTapped(_ sender: Any) {
        let vc = UIStoryboard(name: Constants.Storyboard.Biometrics, bundle: nil)
            .instantiateViewController(withIdentifier: "HRVDetailViewController") as! HRVDetailViewController
        vc.metric = .sdnn
        navigationController?.pushViewController(vc, transitionType: .fade)
    }

    @IBAction func btnHRTapped(_ sender: Any) {
        let vc = UIStoryboard(name: Constants.Storyboard.Biometrics, bundle: nil)
            .instantiateViewController(withIdentifier: "HeartRateDetailViewController") as! HeartRateDetailViewController
        self.navigationController?.pushViewController(vc, transitionType: .fade)
    }

    @IBAction func btnRestingHRTapped(_ sender: Any) {
        let vc = UIStoryboard(name: Constants.Storyboard.Biometrics, bundle: nil)
            .instantiateViewController(withIdentifier: "RestingHeartRateDetailViewController") as! RestingHeartRateDetailViewController
        self.navigationController?.pushViewController(vc, transitionType: .fade)
    }

    @IBAction func btnStepsTapped(_ sender: Any) {
        let vc = UIStoryboard(name: Constants.Storyboard.Biometrics, bundle: nil)
            .instantiateViewController(withIdentifier: "StepsDetailViewController") as! StepsDetailViewController
        self.navigationController?.pushViewController(vc, transitionType: .fade)
    }

    @IBAction func btnSleepDataTapped(_ sender: Any) {
        let vc = UIStoryboard(name: Constants.Storyboard.Biometrics, bundle: nil)
            .instantiateViewController(withIdentifier: "SleepInsightViewController")
        self.navigationController?.pushViewController(vc, transitionType: .fade)
    }
    
    @IBAction func didTapFlowerIcon(_ sender: Any) {
        let deviceManagerVC = UIStoryboard(name: Constants.Storyboard.Devices, bundle: nil).instantiateViewController(withIdentifier: "DeviceManagementViewController") as! DeviceManagementViewController
        self.navigationController?.pushViewController(deviceManagerVC)
    }
    
    @IBAction func didTapProfileIcon(_ sender: Any) {
        self.navigationController?.pushViewController(UIStoryboard(name: Constants.Storyboard.ProfileHost, bundle: nil).instantiateViewController(withIdentifier: "ProfileTabsHostViewController") as! ProfileTabsHostViewController,transitionType: .fade)
    }
    
    @IBAction func didTapCalendarIcon(_ sender: Any) {
        let calendarVC = UIStoryboard(name: Constants.Storyboard.Home, bundle: nil).instantiateViewController(withIdentifier: "CalendarViewController") as! CalendarViewController
        self.navigationController?.pushViewController(calendarVC)
    }

    private enum Prefs {
        static let hideSleepInfo = "ct.prefs.hideSleepInfo"
    }

    @IBAction func btnAddDataTapped(_ sender: Any) {
        if UserDefaults.standard.bool(forKey: Prefs.hideSleepInfo) {
            openHealthAppForSleep()
            return
        }
        presentSleepInfoSheet()
    }

    private func presentSleepInfoSheet() {
        let sheet = UIHostingController(
            rootView: SleepInfoSheetView(
                onAdd: { [weak self] dontShow in
                    if dontShow { UserDefaults.standard.set(true, forKey: Prefs.hideSleepInfo) }
                    self?.openHealthAppForSleep()
                },
                onLater: { dontShow in
                    if dontShow { UserDefaults.standard.set(true, forKey: Prefs.hideSleepInfo) }
                }
            )
        )
        sheet.view.backgroundColor = .black
        sheet.modalPresentationStyle = .pageSheet
        if let sp = sheet.sheetPresentationController {
            if #available(iOS 16.0, *) {
                sp.detents = [.medium(), .large()]
            } else {
                sp.detents = [.medium()]
            }
            sp.prefersGrabberVisible = true
        }
        present(sheet, animated: true)
    }

    // Best-effort: open Health. If it fails, show inline instructions alert.
    private func openHealthAppForSleep() {
        guard let url = URL(string: "x-apple-health://") else { showHealthInstructionsFallback(); return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { ok in
                if !ok { self.showHealthInstructionsFallback() }
            }
        } else {
            showHealthInstructionsFallback()
        }
    }

    private func showHealthInstructionsFallback() {
        let msg = """
        Health → Browse → Sleep → Add Data → choose In Bed/Asleep → set Start & End → Add.
        """
        let alert = UIAlertController(title: "How to add sleep", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
