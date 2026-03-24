//
//  ScannerViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 18/03/26.
//


import UIKit

final class ScannerViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private let vm = ScannerViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTable()
        bind()

        vm.loadInitialData()
        vm.startTimer()
        vm.startMockSocket()
    }

    private func setupTable() {
        tableView.register(ScannerRowCell.self, forCellReuseIdentifier: ScannerRowCell.id)
        tableView.dataSource = self
        tableView.delegate = self

        tableView.rowHeight = 44
        tableView.isScrollEnabled = false
        tableView.separatorStyle = .none
        tableView.backgroundColor = .black
    }

    private func bind() {
        vm.onUpdate = { [weak self] in
            self?.updateVisibleCells()
        }
    }
    
    private func updateVisibleCells() {
        guard let visible = tableView.indexPathsForVisibleRows else { return }

        for indexPath in visible {
            if let cell = tableView.cellForRow(at: indexPath) as? ScannerRowCell {
                cell.configure(with: vm.items[indexPath.row])
            }
        }
    }
}

// MARK: - DataSource
extension ScannerViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return vm.items.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(
            withIdentifier: ScannerRowCell.id,
            for: indexPath
        ) as! ScannerRowCell

        cell.configure(with: vm.items[indexPath.row])
        return cell
    }
}

extension ScannerViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = vm.items[indexPath.row]
        presentNewsDrawer(for: item)
    }
    
    private func presentNewsDrawer(for item: ScannerItem) {

        let vc = NewsDrawerViewController()
        vc.symbol = item.symbol
        vc.hasNews = item.hasNews

        vc.modalPresentationStyle = .pageSheet

        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }

        present(vc, animated: true)
    }
}
