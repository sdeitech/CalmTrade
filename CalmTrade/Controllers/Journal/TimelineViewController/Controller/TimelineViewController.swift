//
//  TimelineViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/01/26.
//

import UIKit

final class TimelineViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var lblSessionDate: UILabel!
    @IBOutlet weak var lblSessionSummary: UILabel!
    @IBOutlet weak var tableView: UITableView!

    // MARK: - ViewModel
    var viewModel: TimelineViewModel!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        setupTable()
        bindViewModel()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        viewModel.fetch()
    }

    // MARK: - Setup
    private func setupTable() {
        tableView.dataSource = self
        tableView.delegate = self

        // If using storyboard prototype cell → DO NOT register class
        // If using XIB → register nib instead
        // tableView.register(TimelineCell.self, forCellReuseIdentifier: "TimelineCell")

        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableView.automaticDimension
    }

    // MARK: - Bindings
    private func bindViewModel() {

        viewModel.onReload = { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }

        viewModel.onSummary = { [weak self] attr in
            DispatchQueue.main.async {
                self?.updateSessionDateLabel()
                self?.lblSessionSummary.attributedText = attr
            }
        }
    }
    
    private func updateSessionDateLabel() {
        let inputFormatter = DateFormatter()
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        inputFormatter.dateFormat = "yyyy-MM-dd"

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "en_US_POSIX")
        outputFormatter.dateFormat = "MMM d, yyyy"

        guard let date = inputFormatter.date(from: viewModel.selectedDate) else {
            lblSessionDate.text = "Session: —"
            return
        }

        lblSessionDate.text = "Session: \(outputFormatter.string(from: date))"
    }
}

extension TimelineViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {

        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "TimelineCell",
            for: indexPath
        ) as? TimelineCell else {
            return UITableViewCell()
        }

        let item = viewModel.item(at: indexPath.section)
        cell.configure(with: item)
        cell.selectionStyle = .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 15.0
    }
}
