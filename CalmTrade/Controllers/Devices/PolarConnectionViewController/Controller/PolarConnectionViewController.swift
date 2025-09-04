//
//  PolarConnectionViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/09/25.
//


import UIKit

class PolarConnectionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var statusLabel: UILabel!
    
    // MARK: - Properties
    private let viewModel = PolarConnectionViewModel()

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        setupViewModelBindings()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        statusLabel.text = "Searching"
        viewModel.startSearch()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopSearch()
    }
    
    // MARK: - Setup
    private func setupViewModelBindings() {
        viewModel.onDeviceListUpdated = { [weak self] in
            self?.tableView.reloadData()
            self?.statusLabel.text = self?.viewModel.discoveredDevices.isEmpty ?? true ? "Searching..." : "Select a device to connect"
        }
        
        viewModel.onStateChanged = { [weak self] status in
            self?.statusLabel.text = status
        }
        
        viewModel.onConnectionSuccess = { [weak self] deviceName in
            self?.statusLabel.text = deviceName
            
            if deviceName.contains("H10") {
                self?.showH10ConnectedPopup()
            } else {
                self?.show360ConnectedPopup()
            }
        }

        
        viewModel.onConnectionFailed = { [weak self] errorMessage in
            // Show an error alert
            self?.showAlert(message: errorMessage)
        }
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.discoveredDevices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)
        let device = viewModel.discoveredDevices[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = device.name
        content.secondaryText = device.id
        cell.contentConfiguration = content
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.connect(at: indexPath.row)
    }
    
    // MARK: - UI Helpers
    private func showConnectedPopup(message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
//            self?.navigationController?.popViewController(animated: true)
            
        }))
        present(alert, animated: true)
    }
    
    private func showH10ConnectedPopup() {
        let vc = UIStoryboard(name: Constants.Storyboard.Devices, bundle: nil).instantiateViewController(withIdentifier: "PolarH10ConnectedViewController") as! PolarH10ConnectedViewController
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        
        vc.continueHandler = { [weak self] in
            // Define what happens when the user taps "Continue"
            self?.dismiss(animated: true) {
                // 2. Then, push the next view controller.
                let breathingVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "BreathingViewController") as! BreathingViewController
                self?.navigationController?.pushViewController(breathingVC, transitionType: .fade)
            }
        }
        present(vc, animated: true)
    }

    private func show360ConnectedPopup() {
        let vc = UIStoryboard(name: Constants.Storyboard.Devices, bundle: nil).instantiateViewController(withIdentifier: "Polar360ConnectedViewController") as! Polar360ConnectedViewController
        vc.modalPresentationStyle = .overCurrentContext
        vc.modalTransitionStyle = .crossDissolve
        
        vc.continueHandler = { [weak self] in
            self?.dismiss(animated: true) {
                // 2. Then, push the next view controller.
                let breathingVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "BreathingViewController") as! BreathingViewController
                self?.navigationController?.pushViewController(breathingVC, transitionType: .fade)
            }
        }
        present(vc, animated: true)
    }
}
