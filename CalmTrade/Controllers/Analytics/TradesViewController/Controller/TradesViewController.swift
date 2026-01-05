//
//  TradesViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 24/11/25.
//

import UIKit

final class TradesViewController: UIViewController {

    // MARK: - UI
    @IBOutlet weak var scrollView: UIScrollView!                 // horizontal scroll only
    @IBOutlet weak var collectionView: UICollectionView!         // vertical scroll
    @IBOutlet weak var collectionWidthConstraint: NSLayoutConstraint!

    // MARK: - ViewModel
    private let viewModel = TradesViewModel()

    // MARK: - Grid Model
    private var grid: [TradeGridRow] = []
    
    private let refreshControl = UIRefreshControl()

    var selectedMonth: Int = 11
    var selectedYear: Int = 2025

    // MARK: - Columns
    private let columns = ["DATE", "SYMBOL", "VOLUME", "EXEC", "P&L"]

    private let columnWidths: [CGFloat] = [
        110, // DATE
        100, // SYMBOL
        90,  // VOLUME
        70,  // EXEC
        120  // P & L
    ]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        refreshControl.addTarget(self, action: #selector(onRefresh), for: .valueChanged)
        scrollView.refreshControl = refreshControl

        setupCollectionView()
        bindViewModel()
        viewModel.load(month: selectedMonth, year: selectedYear)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        syncAndReload()
    }

    private func setupCollectionView() {

        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.backgroundColor = .black
        view.backgroundColor = .black
        scrollView.backgroundColor = .black

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 6          // row spacing like TraderVue
        layout.minimumInteritemSpacing = 1
        collectionView.setCollectionViewLayout(layout, animated: false)
    }

    private func bindViewModel() {
        viewModel.onData = { [weak self] trades in
            guard let self else { return }

            self.buildGrid(from: trades)
            self.updateGridWidth()
            self.collectionView.reloadData()
        }
    }
    
    private func syncAndReload() {
        BrokerSyncManager.shared.syncIfNeeded(fullSync: false) { [weak self] in
            self?.viewModel.refresh()
            self?.refreshControl.endRefreshing()
        }
    }

    @objc private func onRefresh() {
        syncAndReload()
    }

    // MARK: - Build Grid with Totals + Average
    private func buildGrid(from trades: [TradeItem]) {
        grid.removeAll()

        // HEADER
        grid.append(
            TradeGridRow(
                values: columns,
                colors: Array(repeating: .lightGray, count: columns.count),
                isSummary: true
            )
        )

        var totalVolume = 0
        var totalPL: Double = 0

        // DATA ROWS
        for t in trades {
            let pnlColor = t.pnl >= 0 ? UIColor.systemGreen : UIColor.systemRed
            let formatted = String(format: "%.2f", abs(t.pnl))

            totalVolume += t.volume
            totalPL += t.pnl

            grid.append(
                TradeGridRow(
                    values: [
                        t.date,
                        t.symbol,
                        "\(t.volume)",
                        "\(t.executions)",
                        t.pnl >= 0 ? "$\(formatted)" : "-$\(formatted)"
                    ],
                    colors: [.white, .white, .white, .white, pnlColor],
                    isSummary: false
                )
            )
        }

        // TOTAL ROW
        let formattedTotal = String(format: "%.2f", abs(totalPL))

        grid.append(
            TradeGridRow(
                values: [
                    "TOTAL:",
                    "\(trades.count) trades",
                    "\(totalVolume)",
                    "",
                    totalPL >= 0 ? "$\(formattedTotal)" : "-$\(formattedTotal)"
                ],
                colors: [
                    .yellow,
                    .yellow,
                    .white,
                    .white,
                    totalPL >= 0 ? .systemGreen : .systemRed
                ],
                isSummary: true
            )
        )

        // AVERAGE ROW
        let avgPL = trades.count == 0 ? 0 : totalPL / Double(trades.count)
        let formattedAvg = String(format: "%.2f", abs(avgPL))

        grid.append(
            TradeGridRow(
                values: [
                    "AVERAGE:",
                    "",
                    "",
                    "",
                    avgPL >= 0 ? "$\(formattedAvg)" : "-$\(formattedAvg)"
                ],
                colors: [
                    .yellow,
                    .white,
                    .white,
                    .white,
                    avgPL >= 0 ? .systemGreen : .systemRed
                ],
                isSummary: true
            )
        )
    }

    // MARK: - Horizontal Width Calculation
    private func updateGridWidth() {
        let spacing: CGFloat = 1
        let totalSpacing = spacing * CGFloat(columns.count - 1)
        let totalWidth = columnWidths.reduce(0, +) + totalSpacing

        collectionWidthConstraint.constant = totalWidth
        view.layoutIfNeeded()
    }
}


// MARK: - UICollectionViewDataSource
extension TradesViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        grid.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        columns.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "GridTextCell",
            for: indexPath
        ) as! GridTextCell

        let row = grid[indexPath.section]
        let col = indexPath.item

        cell.label.text = row.values[col]
        if let color = row.colors[col] {
            cell.label.textColor = color
        }

        // ALIGN RIGHT ONLY FOR LAST COLUMN
        cell.label.textAlignment = col == columns.count - 1 ? .right : .left

        // HEADER
        if indexPath.section == 0 {
            cell.applyHeaderStyle()
        }
        // SUMMARY ROWS
        else if row.isSummary {
            cell.applySummaryStyle()
        }
        // NORMAL ROWS
        else {
            let isEven = indexPath.section % 2 == 0
            cell.applyRegularStyle(isEven: isEven)
        }

        return cell
    }
}


// MARK: - UICollectionViewDelegateFlowLayout
extension TradesViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {

        let col = indexPath.item
        return CGSize(width: columnWidths[col], height: 50)
    }
}
