//
//  DataManagementViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 29/01/26.
//


import UIKit
import KRProgressHUD

final class DataManagementViewController: UIViewController {

    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!

    private let viewModel = DataManagementViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
    }

    private func bindViewModel() {

        viewModel.onLoading = { isLoading in
            isLoading ? KRProgressHUD.show() : KRProgressHUD.dismiss()
        }
        
        viewModel.onSuccess = { [weak self] message in
            self?.showSuccessAndPop(message: message)
        }

        viewModel.onError = { [weak self] msg in
            self?.showAlert(message: msg)
        }
    }
    
    // MARK: - Actions
    @IBAction func exportDataTapped(_ sender: UIButton) {
        viewModel.exportData()
    }
    
    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }

    @IBAction func deleteAllDataTapped(_ sender: UIButton) {
        let vc = DeleteAllDataBottomSheetViewController()
        vc.modalPresentationStyle = .overFullScreen
        vc.onConfirm = { [weak self] in
            self?.viewModel.deleteAllData()
        }
        present(vc, animated: true)
    }

    private func handleDeleteSuccess() {
        // Pop back (or reset app state)
        navigationController?.popViewController()
    }
    
    // MARK: - Helpers
    private func showSuccessAndPop(message: String) {
        let alert = UIAlertController(title: "Success",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.navigationController?.popViewController()
        })
        present(alert, animated: true)
    }
}
