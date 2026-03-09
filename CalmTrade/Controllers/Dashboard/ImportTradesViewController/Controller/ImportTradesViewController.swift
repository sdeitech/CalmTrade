//
//  ImportTradesViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/11/25.
//

import UIKit
import MobileCoreServices
import UniformTypeIdentifiers
import KRProgressHUD
import WebKit

final class ImportTradesViewController: BaseViewController, UIDocumentPickerDelegate {

    // MARK: - Outlets
    @IBOutlet private weak var brokerButton: UIButton!
    @IBOutlet private weak var accountNameField: UITextField!
    @IBOutlet private weak var requireAccountCheckbox: UIButton!
    @IBOutlet private weak var timezoneField: UITextField!
    @IBOutlet private weak var brokerField: UITextField!
    @IBOutlet private weak var uploadButton: UIButton!
    @IBOutlet private weak var importButton: UIButton!
    @IBOutlet private weak var viewAccountName: UIView!
    @IBOutlet private weak var viewTimezone: UIView!
    @IBOutlet private weak var viewBroker: UIView!
    @IBOutlet private weak var segmentControl: UISegmentedControl!

    private let viewModel = ImportTradesViewModel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
        setupUI()
    }

    private func setupUI() {
        timezoneField.isUserInteractionEnabled = true
        timezoneField.placeholder = "Select Local Time Zone"
        accountNameField.delegate = self
    }

    private func setupBindings() {
        viewModel.onLoading = { [weak self] loading in
            self?.view.isUserInteractionEnabled = !loading
            loading ? LoaderManager.shared.show() : LoaderManager.shared.hide()
        }

        viewModel.onError = { [weak self] msg in
            self?.showAlert(message: msg)
        }

        viewModel.onToast = { [weak self] msg in
            self?.showAlert(message: msg)
        }

        viewModel.onImportSuccess = { [weak self] in
            self?.navigationController?.popViewController()
        }

        viewModel.onBrokerConnect = { [weak self] redirectURL in
            self?.openBrokerConnectWebView(url: redirectURL)
        }
        
        viewModel.onAccountsLoaded = { [weak self] accounts in
            guard let self else { return }

            if accounts.isEmpty {
                // Hide broker view since no connected accounts exist
                self.brokerField.text = ""
                self.viewBroker.isHidden = true
            } else {
                // Show broker dropdown
                self.viewBroker.isHidden = false

                // Auto-select first account for display
                if let first = accounts.first {
                    self.brokerField.text = first.accountName
                    self.viewModel.selectedBroker = first.accountName
                }
            }
        }
    }
    
    private func checkAccessToBrokerSync() -> Bool {
        switch FeatureGate.shared.access(for: FeatureKey.brokerSync) {
        case .allowed:
            return true
        case .locked:
            return false
        }
    }

    // MARK: - Actions
    @IBAction func brokerButtonTapped(_ sender: UIButton) {
        if viewModel.connectedAccounts.isEmpty {
            showBrokerList()
            return
        }
        
        let alert = UIAlertController(title: "Select Account", message: nil, preferredStyle: .actionSheet)
        
        for acc in viewModel.connectedAccounts {
            alert.addAction(UIAlertAction(title: acc.accountName, style: .default) { _ in
                self.brokerField.text = acc.accountName
                self.viewModel.selectedBroker = acc.accountName
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @IBAction func checkboxTapped(_ sender: UIButton) {
        sender.isSelected.toggle()
        viewModel.shouldAlwaysRequireAccount = sender.isSelected
    }

    @IBAction func timezoneTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: Constants.Storyboard.Profile, bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "LocalTimeZoneViewController") as? LocalTimeZoneViewController else { return }

        vc.modalPresentationStyle = .fullScreen
        vc.hidesBackButton = true

        vc.onTimezoneSelected = { [weak self] zoneID, friendlyName in
            self?.viewModel.selectedTimezone = zoneID
            self?.timezoneField.text = friendlyName
            self?.dismiss(animated: true)
        }

        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    @IBAction func uploadTapped(_ sender: UIButton) {
        let supportedTypes: [UTType] = [
            .commaSeparatedText,
            .spreadsheet,
            .pdf,
            .jpeg,
            .png
        ]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = self
        present(picker, animated: true)
    }

    @IBAction func importTapped(_ sender: UIButton) {

        if segmentControl.selectedSegmentIndex == 0 {
            // BROKER SYNC MODE
            viewModel.connectBroker()
            return
        }

        // FILE IMPORT MODE
        viewModel.accountName = accountNameField.text ?? ""
        viewModel.validateAndImport()
    }

    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            if checkAccessToBrokerSync() {
                // Broker Sync Mode
                importButton.setTitle("Connect Broker", for: .normal)
                viewTimezone.isHidden = true
                viewAccountName.isHidden = true
                uploadButton.isHidden = true
                
                // Fetch broker accounts immediately
                viewModel.fetchConnectedAccounts()
            } else {
                sender.selectedSegmentIndex = 1
                FeatureGate.shared.presentUpgradeSheet(for: FeatureKey.brokerSync, from: self)
            }

        } else {
            // File Import Mode
            importButton.setTitle("Import Trades", for: .normal)
            viewBroker.isHidden = false
            viewTimezone.isHidden = false
            viewAccountName.isHidden = false
            uploadButton.isHidden = false
        }
    }
    
    @IBAction func backButtonTapped(_ sender: UIButton) {
        self.navigationController?.popViewController()
    }

    // MARK: - Document Picker
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }

        do {
            let data = try Data(contentsOf: url)
            viewModel.selectedFileData = data
            viewModel.selectedFileName = url.lastPathComponent
            viewModel.selectedFileMime = mimeType(for: url)

            uploadButton.backgroundColor = #colorLiteral(red: 0.3019607843, green: 0.5764705882, blue: 0.5137254902, alpha: 0.7556410498)
            uploadButton.setTitle("Selected: \(url.lastPathComponent)", for: .normal)

        } catch {
            showAlert(message: "Failed to read selected file.")
        }
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "csv":  return "text/csv"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "pdf":  return "application/pdf"
        case "jpg", "jpeg": return "image/jpeg"
        case "png":  return "image/png"
        default: return "application/octet-stream"
        }
    }

    private func showBrokerList() {
        let alert = UIAlertController(title: "Select Broker", message: nil, preferredStyle: .actionSheet)
        ["Generic Import Format", "Webull", "TD Ameritrade", "Zerodha", "AngelOne"].forEach { broker in
            alert.addAction(UIAlertAction(title: broker, style: .default) { _ in
                self.brokerField.text = broker
                self.viewModel.selectedBroker = broker
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Redirect WebView
    private func openBrokerConnectWebView(url: String) {
        let vc = BrokerWebViewController()
        vc.initialURL = url
        vc.viewModel = self.viewModel   // ← VERY IMPORTANT
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - TextField Delegate
extension ImportTradesViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return true
    }
}
