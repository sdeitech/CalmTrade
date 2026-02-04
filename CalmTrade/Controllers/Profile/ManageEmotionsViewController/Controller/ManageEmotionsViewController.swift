//
//  ManageEmotionsViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 21/01/26.
//

import UIKit
import SwiftUI

final class ManageEmotionsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private let viewModel = ManageEmotionsViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTable()
        bind()
        viewModel.fetchTags()
    }

    private func setupTable() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 56
    }

    private func bind() {
        viewModel.onReload = { [weak self] in
            self?.tableView.reloadData()
        }
    }

    private func presentEditor(
        title: String,
        colorHex: String,
        initial: String?,
        onSave: @escaping (String) -> Void
    ) {
        let sheet = UIHostingController(
            rootView: EditEmotionSheet(
                title: title,
                color: Color(uiColor: .init(hex: colorHex)),
                initialText: initial,
                onSave: onSave
            )
        )
        sheet.modalPresentationStyle = .pageSheet
        sheet.sheetPresentationController?.detents = [.medium()]
        present(sheet, animated: true)
    }
    
    // MARK: -- Actions
    @IBAction func btnBackClk(_ sender: UIButton) {
        self.navigationController?.popViewController()
    }
}

extension ManageEmotionsViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.numberOfSections()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfRows(in: section)
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(
            withIdentifier: "ManageEmotionCell",
            for: indexPath
        ) as! ManageEmotionCell

        let category = viewModel.category(at: indexPath.section)
        let emotion = viewModel.tag(at: indexPath)
        let color = UIColor(hex: category.colorHex)
        
        // Encode indexPath
        cell.btnAdd.tag = indexPath.section
        cell.btnAdd.accessibilityValue = "\(indexPath.row)"
        
        cell.btnEdit.tag = indexPath.section
        cell.btnEdit.accessibilityValue = "\(indexPath.row)"
        
        cell.btnDelete.tag = indexPath.section
        cell.btnDelete.accessibilityValue = "\(indexPath.row)"
        
        // Targets
        cell.btnAdd.addTarget(self, action: #selector(addTapped(_:)), for: .touchUpInside)
        cell.btnEdit.addTarget(self, action: #selector(editTapped(_:)), for: .touchUpInside)
        cell.btnDelete.addTarget(self, action: #selector(deleteTapped(_:)), for: .touchUpInside)
        
        cell.configure(emotion: emotion, color: color)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        let category = viewModel.category(at: section)

        let container = UIView()
        container.backgroundColor = .black

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        switch category.name {
        case "Positive":
            label.text = "Positive / Flow Emotions"
        case "Negative":
            label.text = "Negative / Stress Emotions"
        case "Neutral":
            label.text = "Neutral / Ambiguous Emotions"
        case "Cognitive":
            label.text = "Cognitive Insight Tags"
        default:
            label.text = category.name
        }
        label.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        label.textColor = UIColor(hex: category.colorHex)

        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 12)
        ])

        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }
    
    @objc private func addTapped(_ sender: UIButton) {
        guard let indexPath = indexPath(from: sender) else { return }
        let category = viewModel.category(at: indexPath.section)

        presentEditor(
            title: category.name,
            colorHex: category.colorHex,
            initial: nil
        ) {
            self.viewModel.createTag(
                name: $0,
                section: indexPath.section
            )
        }
    }

    @objc private func editTapped(_ sender: UIButton) {
        guard let indexPath = indexPath(from: sender),
              let emotion = viewModel.tag(at: indexPath)
        else { return }

        let category = viewModel.category(at: indexPath.section)

        presentEditor(
            title: category.name,
            colorHex: category.colorHex,
            initial: emotion.name
        ) {
            self.viewModel.updateTag(
                name: $0,
                section: indexPath.section,
                row: indexPath.row
            )
        }
    }

    @objc private func deleteTapped(_ sender: UIButton) {
        guard let indexPath = indexPath(from: sender),
              let emotion = viewModel.tag(at: indexPath)
        else { return }
        viewModel.deleteTag(section: indexPath.section, row: indexPath.row)
    }
    
    private func indexPath(from sender: UIButton) -> IndexPath? {
        guard
            let rowString = sender.accessibilityValue,
            let row = Int(rowString)
        else { return nil }

        return IndexPath(row: row, section: sender.tag)
    }
}
