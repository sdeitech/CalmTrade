//
//  OverallStatsViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 10/11/25.
//


import UIKit
import Combine
import KRProgressHUD

final class OverallStatsViewController: BaseViewController {
    
    // MARK: - UI
    @IBOutlet private weak var tableView: UITableView!
    
    private var cancellables = Set<AnyCancellable>()
    private let viewModel = OverallStatsViewModel()
    private var rows: [(label: String, value: String, color: UIColor?)] = []
    private let refreshControl = UIRefreshControl()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        refreshControl.addTarget(self, action: #selector(onRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        setupUI()
        bindViewModel()
        
        // Example call (replace accountId and date range with real filters)
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let end = Date()
        viewModel.fetchOverallStats(accountId: "123", from: start, to: end)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        syncAndReload()
    }
    
    private func setupUI() {
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
//        emptyLabel.isHidden = true
    }
    
    private func bindViewModel() {
        viewModel.$stats
            .sink { [weak self] stats in
                guard let self = self else { return }
                if let stats {
                    self.updateRows(with: stats)
                    self.tableView.reloadData()
//                    self.emptyLabel.isHidden = true
                } else {
//                    self.emptyLabel.text = "No stats yet. Place some trades to see your performance."
//                    self.emptyLabel.isHidden = false
                }
            }
            .store(in: &cancellables)
        
        viewModel.$isLoading
            .sink { [weak self] loading in
                loading ? KRProgressHUD.show() : KRProgressHUD.dismiss()
            }
            .store(in: &cancellables)
        
        viewModel.$errorMessage
            .sink { [weak self] msg in
                guard let msg else { return }
                self?.showAlert(message: msg)
            }
            .store(in: &cancellables)
    }
    
    private func syncAndReload() {
        let accountId = SessionManager.shared.current?.accountId ?? ""
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let end = Date()

        BrokerSyncManager.shared.syncIfNeeded(fullSync: false) { [weak self] in
            self?.viewModel.fetchOverallStats(accountId: accountId, from: start, to: end)
            self?.refreshControl.endRefreshing()
        }
    }

    @objc private func onRefresh() {
        syncAndReload()
    }

    
    private func updateRows(with data: OverallStatsData) {
        func color(for value: String?) -> UIColor? {
            guard let val = Double(value ?? "0") else { return .label }
            if val > 0 { return UIColor(named: "gainColor") ?? .systemGreen }
            if val < 0 { return UIColor(named: "lossColor") ?? .systemRed }
            return UIColor(named: "neutralColor") ?? .label
        }

        func color(forDouble value: Double?) -> UIColor? {
            guard let val = value else { return .label }
            if val > 0 { return UIColor(named: "gainColor") ?? .systemGreen }
            if val < 0 { return UIColor(named: "lossColor") ?? .systemRed }
            return UIColor(named: "neutralColor") ?? .label
        }

        func formatDoubleCurrency(_ val: Double?) -> String {
            guard let v = val else { return "--" }
            let absVal = abs(v)
            let symbol = Locale.current.currencySymbol ?? "$"
            return "\(v < 0 ? "-" : "")\(symbol)\(String(format: "%.2f", absVal))"
        }

        rows = [
            ("Total Gain/Loss", formatCurrency(data.totalGainLoss), color(for: data.totalGainLoss)),
            ("Largest Gain", formatCurrency(data.largestGain), color(for: data.largestGain)),
            ("Largest Loss", formatCurrency(data.largestLoss), color(for: data.largestLoss)),
            ("Average Daily Gain/Loss", formatCurrency(data.averageDailyGainLoss), color(for: data.averageDailyGainLoss)),
            ("Average Daily Volume", formatVolume(data.averageDailyVolume), nil),
            ("Average Per-share Gain/Loss", formatCurrency(data.averagePerShareGainLoss), color(for: data.averagePerShareGainLoss)),
            ("Avg. Winner per Share", formatDoubleCurrency(data.avgWinnerPerShare), color(forDouble: data.avgWinnerPerShare)),
            ("Avg. Loser per Share", formatDoubleCurrency(data.avgLoserPerShare), .red),
            ("Average Trade Gain/Loss", formatCurrency(data.averageTradeGainLoss), color(for: data.averageTradeGainLoss)),
            ("Average Winning Trade", formatCurrency(data.averageWinningTrade), color(for: data.averageWinningTrade)),
            ("Average Losing Trade", formatCurrency(data.averageLosingTrade), .red),
            ("Profit Factor", String(format: "%.4f", data.profitFactor ?? 0), data.profitFactor ?? 0.0 > 1 ? .green : .red),
            ("Total Number of Trades", "\(data.totalTrades ?? 0)", nil),
            ("Number of Winning Trades", "\(data.winningTrades ?? 0) (\(data.winningPercent ?? "--"))", nil),
            ("Number of Losing Trades", "\(data.losingTrades ?? 0) (\(data.losingPercent ?? "--"))", nil)
        ]
    }

    
    private func formatCurrency(_ str: String?) -> String {
        guard let s = str, let val = Double(s) else { return "--" }
        let absVal = abs(val)
        let symbol = Locale.current.currencySymbol ?? "$"
        return "\(val < 0 ? "-" : "")\(symbol)\(String(format: "%.2f", absVal))"
    }
    
    private func formatVolume(_ str: String?) -> String {
        guard let s = str, let val = Int(s) else { return "--" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: val)) ?? "\(val)"
    }
    
    // MARK: - Actions
    
    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }
}

extension OverallStatsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StatsCell") ??
            UITableViewCell(style: .value1, reuseIdentifier: "StatsCell")
        let row = rows[indexPath.row]
        cell.textLabel?.text = row.label
        cell.detailTextLabel?.text = row.value
        cell.detailTextLabel?.textColor = row.color ?? .label
        return cell
    }
}
