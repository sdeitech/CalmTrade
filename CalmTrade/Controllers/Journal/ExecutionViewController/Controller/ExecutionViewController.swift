//
//  ExecutionViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 12/01/26.
//

import UIKit

final class ExecutionViewController: UIViewController {

    // MARK: - UI
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionWidthConstraint: NSLayoutConstraint!

    // MARK: - ViewModel
    let viewModel = ExecutionViewModel()

    // MARK: - Grid
    private var grid: [TradeGridRow] = []
    private let refreshControl = UIRefreshControl()

    // Selected date (yyyy-MM-dd)
    var selectedDate: String = "2026-01-05"

    // MARK: - Columns
    private let columns = ["TIME", "SYMBOL", "PRICE", "SIDE", "SIZE", "P&L"]

    private let columnWidths: [CGFloat] = [
        80,   // TIME
//        180,  // TIMESTAMP
        90,
        100,  // SYMBOL
        80,   // SIDE
        80,   // SIZE
        120   // P&L
    ]
    
    private var hasExecutionAccess: Bool {
        switch FeatureGate.shared.access(for: FeatureKey.journalUnlocked) {
        case .allowed:
            true
        case .locked:
            false
        }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        refreshControl.addTarget(self, action: #selector(onRefresh), for: .valueChanged)
        scrollView.refreshControl = refreshControl

        setupCollectionView()
        bindViewModel()

        viewModel.load(date: selectedDate)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncAndReload()
    }

    private func setupCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self

        view.backgroundColor = .black
        scrollView.backgroundColor = .black
        collectionView.backgroundColor = .black

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 6
        layout.minimumInteritemSpacing = 1
        collectionView.setCollectionViewLayout(layout, animated: false)
    }

    private func bindViewModel() {
        viewModel.onData = { [weak self] executions in
            guard let self else { return }
            self.buildGrid(from: executions)
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

    // MARK: - Grid Builder
    private func buildGrid(from executions: [ExecutionItem]) {

        grid.removeAll()

        // HEADER
        grid.append(
            TradeGridRow(
                values: columns,
                colors: Array(repeating: .lightGray, count: columns.count),
                isSummary: true
            )
        )

        var totalPnL: Double = 0
        let totalPrice = executions.compactMap(\.price).reduce(0, +)

        // Always compute totals from ALL executions
        executions.forEach { totalPnL += $0.pnl ?? 0 }

        // Decide what to show
        let visibleExecutions: [ExecutionItem]

        if hasExecutionAccess {
            visibleExecutions = executions
        } else {
            visibleExecutions = Array(executions.prefix(2))
        }

        // EXECUTION ROWS
        for e in visibleExecutions {

            let pnl = e.pnl ?? 0
            let pnlColor: UIColor =
                pnl > 0 ? .systemGreen :
                pnl < 0 ? .systemRed :
                .lightGray

            let price = e.price ?? 0

            grid.append(
                TradeGridRow(
                    values: [
                        TimelineDateFormatter.time(from: e.timestamp) ?? "-",
                        e.symbol,
                        e.price != nil
                            ? String(format: "$%.2f", price)
                            : "-",
                        e.side,
                        e.size.map { "\($0)" } ?? "-",
                        e.pnl != nil
                            ? String(format: "$%.2f", pnl)
                            : "-"
                    ],
                    colors: [
                        .white,
                        .white,
                        .white,
                        e.side.lowercased() == "buy" ? .systemGreen : .systemRed,
                        .white,
                        pnlColor
                    ],
                    isSummary: false
                )
            )
        }

        // VIEW ALL ROW (only if locked and more than 2)
        if !hasExecutionAccess && executions.count > 2 {

            grid.append(
                TradeGridRow(
                    values: [
                        "",
                        "View All 🔒",
                        "",
                        "",
                        "",
                        ""
                    ],
                    colors: [
                        .clear,
                        .systemYellow,
                        .clear,
                        .clear,
                        .clear,
                        .clear
                    ],
                    isSummary: true
                )
            )
        }

        // TOTAL ROW
        grid.append(
            TradeGridRow(
                values: [
                    "TOTAL",
                    "\(executions.count) executions",
                    "$ \(String(format: "%.2f", totalPrice))",
                    "",
                    "",
                    String(format: "$%.2f", totalPnL)
                ],
                colors: [
                    .yellow,
                    .yellow,
                    .white,
                    .white,
                    .white,
                    totalPnL >= 0 ? .systemGreen : .systemRed
                ],
                isSummary: true
            )
        )
    }

    private func updateGridWidth() {
        let spacing: CGFloat = 1
        let totalSpacing = spacing * CGFloat(columns.count - 1)
        let totalWidth = columnWidths.reduce(0, +) + totalSpacing
        collectionWidthConstraint.constant = totalWidth
        view.layoutIfNeeded()
    }
}

extension ExecutionViewController: UICollectionViewDataSource {

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
        cell.label.textColor = row.colors[col] ?? .white
        cell.label.textAlignment = col == columns.count - 1 ? .right : .left

        if indexPath.section == 0 {
            cell.applyHeaderStyle()
        } else if row.isSummary {
            cell.applySummaryStyle()
        } else {
            cell.applyRegularStyle(isEven: indexPath.section % 2 == 0)
        }

        return cell
    }
}

extension ExecutionViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: columnWidths[indexPath.item], height: 50)
    }
}

extension ExecutionViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {

        let row = grid[indexPath.section]

        if row.values.contains("View All 🔒") {
            FeatureGate.shared.presentUpgradeSheet(
                for: FeatureKey.journalUnlocked,
                from: self
            )
        }
    }
}

