//
//  NotesViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 13/01/26.
//


import UIKit

final class NotesViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private let viewModel = NotesViewModel()
    private let refreshControl = UIRefreshControl()

    var selectedDate: Date = Date()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        bindViewModel()
        fetchNotes()
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self

        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(onPullToRefresh), for: .valueChanged)
    }

    private func bindViewModel() {
        viewModel.onLoading = { [weak self] loading in
            if !loading {
                self?.refreshControl.endRefreshing()
            }
        }

        viewModel.onDataReload = { [weak self] in
            self?.tableView.reloadData()
        }

        viewModel.onError = { [weak self] message in
            self?.showAlert(message: message)
        }
    }

    func fetchNotes() {
        viewModel.fetchNotes(for: selectedDate)
    }

    @objc private func onPullToRefresh() {
        fetchNotes()
    }
}

extension NotesViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.numberOfRows()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: NoteTableViewCell.identifier,
            for: indexPath
        ) as! NoteTableViewCell
        cell.selectionStyle = .none
        cell.configure(with: viewModel.note(at: indexPath.section))
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        10.0
    }
}
