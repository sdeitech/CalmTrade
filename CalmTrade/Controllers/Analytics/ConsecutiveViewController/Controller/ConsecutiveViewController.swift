//
//  ConsecutiveViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 01/12/25.
//


// ConsecutiveViewController.swift
import UIKit

final class ConsecutiveViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var segTimeframe: UISegmentedControl!
    @IBOutlet weak var lblWins: UILabel!
    @IBOutlet weak var lblLosses: UILabel!
    @IBOutlet weak var lblInsight: UILabel!

    private let viewModel = ConsecutiveViewModel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
        loadInitial()
    }

    private func bindViewModel() {

        viewModel.winsText = { [weak self] text in
            DispatchQueue.main.async {
                self?.lblWins.text = text
            }
        }

        viewModel.lossesText = { [weak self] text in
            DispatchQueue.main.async {
                self?.lblLosses.text = text
            }
        }

        viewModel.insightText = { [weak self] text in
            DispatchQueue.main.async {
                self?.lblInsight.text = text
            }
        }

        viewModel.showError = { [weak self] message in
            DispatchQueue.main.async {
                self?.showAlert(message)
            }
        }

        viewModel.setLoading = { isLoading in
            DispatchQueue.main.async {
                // integrate KRProgressHUD if needed
                if isLoading {
                    // KRProgressHUD.show()
                } else {
                    // KRProgressHUD.dismiss()
                }
            }
        }
    }

    private func loadInitial() {
        viewModel.fetchConsecutive(filter: "weekly")
    }

    // MARK: - Segmented control
    @IBAction func segTimeframeChanged(_ sender: UISegmentedControl) {
        let filter = mapFilter(sender.selectedSegmentIndex)
        viewModel.fetchConsecutive(filter: filter)
    }

    private func mapFilter(_ index: Int) -> String {
        switch index {
        case 0: return "daily"
        case 1: return "weekly"
        case 2: return "monthly"
        case 3: return "yearly"
        default: return "weekly"
        }
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Error",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

