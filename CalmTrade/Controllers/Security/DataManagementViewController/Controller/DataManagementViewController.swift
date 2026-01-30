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

        viewModel.onSuccess = { [weak self] in
            self?.handleDeleteSuccess()
        }

        viewModel.onError = { [weak self] msg in
            self?.showAlert(message: msg)
        }
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
        navigationController?.popViewController(animated: true)
    }
}
