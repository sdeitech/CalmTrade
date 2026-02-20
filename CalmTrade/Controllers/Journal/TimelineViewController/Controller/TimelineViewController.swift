//
//  TimelineViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/01/26.
//

import UIKit
import SwiftUI

final class TimelineViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var lblSessionDate: UILabel!
    @IBOutlet weak var lblSessionSummary: UILabel!
    @IBOutlet weak var tableView: UITableView!

    // MARK: - ViewModel
    var viewModel: TimelineViewModel!
    private let emptyStateLabel = UILabel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        setupTable()
        bindViewModel()
        updateSessionDateLabel()
        lblSessionSummary.attributedText = TimelineViewModel.emptySummary()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        viewModel.fetch()
    }

    // MARK: - Setup
    private func setupTable() {
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.register(ViewAllLockedCell.self,
                           forCellReuseIdentifier: ViewAllLockedCell.identifier)

        // If using storyboard prototype cell → DO NOT register class
        // If using XIB → register nib instead
        // tableView.register(TimelineCell.self, forCellReuseIdentifier: "TimelineCell")

        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableView.automaticDimension

        emptyStateLabel.text = "No timeline data found."
        emptyStateLabel.textColor = UIColor.init(hex: "CACACA")
        emptyStateLabel.font = .systemFont(ofSize: 14, weight: .regular)
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
    }

    // MARK: - Bindings
    private func bindViewModel() {

        viewModel.onReload = { [weak self] in
            DispatchQueue.main.async {
                self?.updateEmptyState()
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

    private func updateEmptyState() {
        tableView.backgroundView = viewModel.count == 0 ? emptyStateLabel : nil
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

        let displayItem = viewModel.displayItem(at: indexPath.section)

        switch displayItem {

        case .entry(let item):

            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: "TimelineCell",
                for: indexPath
            ) as? TimelineCell else {
                return UITableViewCell()
            }

            cell.configure(with: item)

            cell.onAddNoteTapped = { [weak self] in
                guard let self, let emotionId = item._id else { return }
                self.presentEmotionNoteSheet(emotionId: emotionId, type: item.type)
            }

            return cell

        case .viewAllLocked:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: ViewAllLockedCell.identifier,
                for: indexPath
            ) as! ViewAllLockedCell
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 15.0
    }
    
    private func presentEmotionNoteSheet(emotionId: String, type: TimelineItemType) {

        var typeString: String = ""
        switch type {
        case .Trades:
            typeString = "trade"
        case .Emotion:
            typeString = "emotion"
        case .NoTrade:
            typeString = "no-trade"
        }
        let vm = EmotionNoteViewModel(emotionId: emotionId, typeString: typeString)
        let sheet = EmotionBottomSheetView(
            viewModel: vm,
            onSaved: { [weak self] in
            self?.viewModel.fetch()
        })

        let host = UIHostingController(rootView: sheet)
        host.modalPresentationStyle = .pageSheet
        host.view.backgroundColor = .clear

        if let sheet = host.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = false
        }

        present(host, animated: true)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let item = viewModel.displayItem(at: indexPath.section)

        if case .viewAllLocked = item {
            FeatureGate.shared.presentUpgradeSheet(
                for: FeatureKey.journalUnlocked,
                from: self
            )
        }
    }

    func tableView(_ tableView: UITableView,
                   contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint)
    -> UIContextMenuConfiguration? {

        let displayItem = viewModel.displayItem(at: indexPath.section)

        guard case .entry(let item) = displayItem,
              let id = item._id else {
            return nil
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in

            let delete = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                self?.viewModel.deleteItem(item: item) { _ in }
            }

            return UIMenu(title: "", children: [delete])
        }
    }

}
