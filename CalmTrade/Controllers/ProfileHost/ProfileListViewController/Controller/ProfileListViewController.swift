//
//  ProfileListViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 27/10/25.
//


import UIKit

final class ProfileListViewController: UITableViewController {

    // Inject from Host
    var viewModel: ProfileListViewModel!

    private var rows: [ProfileRow] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        assert(viewModel != nil, "ProfileListViewModel must be injected before presenting")

        bindVM()
        viewModel.load()
    }

    private func bindVM() {
        viewModel.onRows = { [weak self] rows in
            self?.rows = rows
            self?.tableView.reloadData()
        }
    }

    // MARK: - UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileRowCell", for: indexPath) as? ProfileRowCell
        else { return UITableViewCell() }

        let row = rows[indexPath.row]
        let isLast =  indexPath.row == rows.count - 1
        cell.iconView.image = UIImage(named: row.icon)
        cell.titleLabel.text = row.title

        // Optional: group rounding
        if isLast {
            cell.cardView.isHidden = true
        }
        return cell
    }

    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UISelectionFeedbackGenerator().selectionChanged()
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.didSelectRow(at: indexPath.row)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 62 }
}
