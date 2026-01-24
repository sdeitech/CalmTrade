//
//  AppSettingViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 23/01/26.
//

import UIKit

final class AppSettingViewController: UITableViewController {

    // Inject from host
    var viewModel: AppSettingViewModel!

    private var rows: [AppSettingRow] = []

    // MARK: - Header view
    private final class TitleHeaderView: UITableViewHeaderFooterView {
        static let reuseID = "TitleHeaderView"

        let label = UILabel()

        override init(reuseIdentifier: String?) {
            super.init(reuseIdentifier: reuseIdentifier)
            contentView.backgroundColor = .clear

            label.translatesAutoresizingMaskIntoConstraints = false
            label.textColor = UIColor { $0.userInterfaceStyle == .dark ? .white : .black }
            label.font = .systemFont(ofSize: 20, weight: .semibold)

            contentView.addSubview(label)

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
                // 👇 stick label at top (no inset)
                label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
                // keep small bottom inset so table doesn’t clip
                label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
            ])
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        assert(viewModel != nil, "AppSettingViewModel must be injected")

        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)
        tableView.backgroundColor = .clear

        tableView.register(TitleHeaderView.self, forHeaderFooterViewReuseIdentifier: TitleHeaderView.reuseID)

        bindVM()
        viewModel.load()
    }

    private func bindVM() {
        viewModel.onRows = { [weak self] rows in
            self?.rows = rows
            self?.tableView.reloadData()
        }
        // Route to host (hooked up by the host when it injects the VM)
        // viewModel.onRoute = { action in ... }
    }

    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SettingRowCell", for: indexPath) as? ProfileRowCell
        else { return UITableViewCell() }

        let row = rows[indexPath.row]
        let isFirst = indexPath.row == 0
        let isLast  = indexPath.row == rows.count - 1

        cell.iconView.image = UIImage(named: row.iconName)
        cell.titleLabel.text = row.title

        // Reset before applying (important when cells are reused)
        cell.layer.cornerRadius = 15
        cell.layer.maskedCorners = []

        if isFirst && isLast {
            // only one cell in list → round all corners
            cell.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner
            ]
        } else if isFirst {
            // top-only
            cell.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner
            ]
        } else if isLast {
            // bottom-only
            cell.layer.maskedCorners = [
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner
            ]
        }

        cell.layer.masksToBounds = true
        return cell
    }


    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        UISelectionFeedbackGenerator().selectionChanged()
        viewModel.didSelectRow(at: indexPath.row)
    }

    // “Card” spacing and sizes to match your look
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 68 }

    // Single header titled "Security Setting"
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: TitleHeaderView.reuseID) as? TitleHeaderView
        else { return nil }
        header.label.text = viewModel.headerTitle
        return header
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 50 }
}
