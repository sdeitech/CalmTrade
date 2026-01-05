//
//  AnalyticsDashboardViewController.swift
//  CalmTrade
//

import UIKit
import Combine
import SwiftUI

final class AnalyticsDashboardViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var recentButton: UIButton!
    @IBOutlet weak var yearMonthDayButton: UIButton!
    @IBOutlet weak var pnlContainerView: UIView!
    @IBOutlet weak var winRateContainer: UIView!
    @IBOutlet weak var lblAverageCalmscore: UILabel!
    @IBOutlet weak var cumulativePLContainer: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    
    // Avg Gain/Loss
    @IBOutlet weak var avgGainLabel: UILabel!
    @IBOutlet weak var avgLossLabel: UILabel!

    // Profit Factor
    @IBOutlet weak var profitFactorLabel: UILabel!
    @IBOutlet weak var profitFactorImage: UIImageView!

    // Consecutive Win/Loss
    @IBOutlet weak var longestWinLabel: UILabel!
    @IBOutlet weak var longestLossLabel: UILabel!

    // Hold Time
    @IBOutlet weak var holdWinLabel: UILabel!
    @IBOutlet weak var holdLossLabel: UILabel!


    // MARK: - Properties
    private let refreshControl = UIRefreshControl()

    private let viewModel = AnalyticsDashboardViewModel()
    private var cancellation = Set<AnyCancellable>()

    private var pnlHostingVC: UIHostingController<GrossDailyPnLChart>?
    private var winRateHostingVC: UIHostingController<WinRateGauge>?
    private var cumulativePLHostingVC: UIHostingController<GrossCumulativePLChart>?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        refreshControl.addTarget(self, action: #selector(onRefresh), for: .valueChanged)
        scrollView?.refreshControl = refreshControl

        configureUI()
        bindViewModel()
        setupLifecycleObservers()
    }
    
    /// Called EVERY time the Analytics tab becomes visible
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncAndReload()
        refreshAPIs()
    }

    private func configureUI() {
        recentButton.isSelected = true
        yearMonthDayButton.isSelected = false
    }

    // MARK: - App Lifecycle Refresh
    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        refreshAPIs()
    }

    private func refreshAPIs() {
        viewModel.fetchDashboard()
        viewModel.fetchGrossDailyPnL(filter: "monthly")
    }
    
    private func syncAndReload() {
        BrokerSyncManager.shared.syncIfNeeded(fullSync: false) { [weak self] in
            self?.viewModel.fetchDashboard()
            self?.viewModel.fetchGrossDailyPnL(filter: "monthly")
            self?.refreshControl.endRefreshing()
        }
    }

    @objc private func onRefresh() {
        syncAndReload()
    }



    // MARK: - Bind ViewModel
    private func bindViewModel() {

        // Gross Daily PNL
        viewModel.$grossDailyPnL
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.updatePNLChart(list)
            }
            .store(in: &cancellation)

        // Win Rate Gauge
        viewModel.$winRateScore
            .combineLatest(viewModel.$winRateAvgCalmScore)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (score, avg) in
                self?.updateWinRateGauge(score: score, title: avg)
            }
            .store(in: &cancellation)
        
        viewModel.$totalWins
            .combineLatest(viewModel.$totalLosses)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] wins, losses in
                self?.longestWinLabel.text = "\(wins)"
                self?.longestLossLabel.text = "\(losses)"
            }
            .store(in: &cancellation)

        // AVG GAIN LOSS
        viewModel.$avgGain
            .combineLatest(viewModel.$avgLoss)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] gain, loss in
                self?.avgGainLabel.text = String(format: "%.2f", gain)
                self?.avgLossLabel.text = String(format: "%.2f", loss)
            }
            .store(in: &cancellation)

        // PROFIT FACTOR
        viewModel.$profitFactor
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pf in
                self?.profitFactorLabel.text = String(format: "%.2f", pf)
                self?.profitFactorLabel.textColor = pf > 1 ? UIColor("5DC866") : UIColor("B52D0B")
                self?.profitFactorImage.tintColor = pf > 1 ? UIColor("5DC866") : UIColor("B52D0B")
            }
            .store(in: &cancellation)

        // HOLD TIME
        viewModel.$holdWin
            .combineLatest(viewModel.$holdLoss)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] win, loss in
                self?.holdWinLabel.text = win
                self?.holdLossLabel.text = loss
            }
            .store(in: &cancellation)
    }

    // MARK: - Update PNL Chart
    private func updatePNLChart(_ data: [DailyPnLBar]) {
        pnlHostingVC?.view.removeFromSuperview()
        pnlHostingVC?.removeFromParent()

        let chart = GrossDailyPnLChart(items: data)
        let host = UIHostingController(rootView: chart)
        host.view.backgroundColor = .clear
        pnlHostingVC = host

        addChild(host)
        pnlContainerView.addSubview(host.view)

        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: pnlContainerView.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: pnlContainerView.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: pnlContainerView.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: pnlContainerView.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    // MARK: - Update Win Rate Gauge
    private func updateWinRateGauge(score: Double, title: String) {
        lblAverageCalmscore.text = "Average Calmscore: \(title)"
        
        winRateHostingVC?.view.removeFromSuperview()
        winRateHostingVC?.removeFromParent()

        let gauge = WinRateGauge(score: score)
        let host = UIHostingController(rootView: gauge)
        host.view.backgroundColor = .clear
        winRateHostingVC = host

        addChild(host)
        winRateContainer.addSubview(host.view)

        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: winRateContainer.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: winRateContainer.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: winRateContainer.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: winRateContainer.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    // MARK: - Update Cumulative PNL Chart
    private func updateCumulativePLChart(_ data: [CumulativePLPoint]) {
        cumulativePLHostingVC?.view.removeFromSuperview()
        cumulativePLHostingVC?.removeFromParent()

        let chart = GrossCumulativePLChart(items: data)
        let host = UIHostingController(rootView: chart)
        host.view.backgroundColor = .clear
        cumulativePLHostingVC = host

        addChild(host)
        cumulativePLContainer.addSubview(host.view)

        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: cumulativePLContainer.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: cumulativePLContainer.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: cumulativePLContainer.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: cumulativePLContainer.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    // MARK: - Actions
    @IBAction func didTapYearMonthDay(_ sender: UIButton) {
        viewModel.setTimeframe(.custom)
    }

    @IBAction func didTapYear(_ sender: UIButton) {
        let grossDailyPnlDetailView = storyboard?.instantiateViewController(withIdentifier: "GrossDailyPnLViewController") as! GrossDailyPnLViewController
        self.navigationController?.pushViewController(grossDailyPnlDetailView)
    }
    
    @IBAction func didTapWinRateButton(_ sender: UIButton) {
        let vc = storyboard?.instantiateViewController(identifier: "WinRateViewController") as! WinRateViewController
        navigationController?.pushViewController(vc)
    }
    
    @IBAction func didTapConsecutiveButton(_ sender: UIButton) {
        let vc = storyboard?.instantiateViewController(withIdentifier: "ConsecutiveViewController") as! ConsecutiveViewController
        navigationController?.pushViewController(vc)
    }
    
    @IBAction func didTapAverageButton(_ sender: UIButton) {
        let vc = storyboard?.instantiateViewController(withIdentifier: "AverageTradeGainLossViewController") as! AverageTradeGainLossViewController
        navigationController?.pushViewController(vc)
    }
    
    @IBAction func didTapProfitFactorButton(_ sender: UIButton) {
        let vc = storyboard?.instantiateViewController(withIdentifier: "ProfitFactorViewController") as! ProfitFactorViewController
        navigationController?.pushViewController(vc)
    }
    
    @IBAction func didTapGrossCumulativePnlButton(_ sender: UIButton) {
        let vc = storyboard?.instantiateViewController(withIdentifier: "GrossCumulativePLViewController") as! GrossCumulativePLViewController
        navigationController?.pushViewController(vc)
    }
}
