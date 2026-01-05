//
//  PolarConnectionViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/09/25.
//


import UIKit
import HealthKit
import PolarBleSdk

class PolarConnectionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var statusLabel: UILabel!
    
    // MARK: - Properties
    private let viewModel = PolarConnectionViewModel()

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("PolarVC ▶︎ viewDidLoad")
        // Make router attach now that PolarManager.shared is fully initialized
        LiveDataRouter.shared.attachToPolar()

        tableView.dataSource = self
        tableView.delegate = self
        setupViewModelBindings()
    }

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NSLog("PolarVC ▶︎ viewWillAppear → startSearch")
        statusLabel.text = "Searching"
        viewModel.startSearch()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopSearch()
    }
    
    // MARK: - Setup
    private func setupViewModelBindings() {
        // Devices list
        viewModel.onDeviceListUpdated = { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.tableView.reloadData()
                let isEmpty = self.viewModel.discoveredDevices.isEmpty
                self.statusLabel.text = isEmpty ? "Searching..." : "Select a device to connect"
            }
        }

        // Generic status text (from VM)
        viewModel.onStateChanged = { [weak self] status in
            DispatchQueue.main.async {
                self?.statusLabel.text = status
            }
        }

        // Connection results
        viewModel.onConnectionSuccess = { [weak self] deviceName in
            guard let self = self else { return }
            self.statusLabel.text = "Connected to \(deviceName)"
            
            // next step: determine FTU state
            self.viewModel.checkFtuStatus()
        }

        viewModel.onConnectionFailed = { [weak self] errorMessage in
            DispatchQueue.main.async {
                self?.showAlert(message: errorMessage)
            }
        }

        // ---------- Firmware Update wiring (new) ----------

        // 1) Firmware check (available / not / failed)
        viewModel.onFirmwareCheck = { [weak self] check in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch check {
                case .checkFwUpdateAvailable(let version):
                    self.statusLabel.text = "Firmware update available: \(version). Starting…"
                case .checkFwUpdateNotAvailable:
                    // leave current status alone; no need to overwrite
                    break
                case .checkFwUpdateFailed(let details):
                    self.statusLabel.text = "FW check failed"
                    self.showAlert(message: "Firmware check failed: \(details)")
                }
            }
        }

        // 2) Firmware progress/status stream
        viewModel.onFirmwareStatus = { [weak self] status in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch status {
                case .fetchingFwUpdatePackage:
                    self.statusLabel.text = "Downloading firmware…"
                case .preparingDeviceForFwUpdate:
                    self.statusLabel.text = "Preparing device for update…"
                case .writingFwUpdatePackage(let details):
                    // Some SDK builds put % in details, surface if present
                    if let pct = Self.parsePercent(details) {
                        self.statusLabel.text = "Writing firmware… \(pct)%"
                    } else {
                        self.statusLabel.text = "Writing firmware…"
                    }
                case .finalizingFwUpdate:
                    self.statusLabel.text = "Finalizing update…"
                case .fwUpdateCompletedSuccessfully:
                    self.statusLabel.text = "Firmware update completed ✅"
                case .fwUpdateNotAvailable:
                    // no-op; already handled in check phase
                    break
                case .fwUpdateFailed(let details):
                    self.statusLabel.text = "Firmware update failed"
                    self.showAlert(message: "Firmware update failed: \(details)")
                }
            }
        }

        // 3) Firmware stream errors (transport/observable)
        viewModel.onFirmwareError = { [weak self] error in
            DispatchQueue.main.async {
                self?.statusLabel.text = "Firmware error"
                self?.showAlert(message: error.localizedDescription)
            }
        }
        
        // If FTU needed → open FTU screen
        viewModel.onFirstTimeUseNeeded = { [weak self] _ in
            DispatchQueue.main.async {
                self?.presentPolar360FTU()
            }
        }

        // If FTU is already done → now show connected popup
        viewModel.onFtuNotNeeded = { [weak self] in
            DispatchQueue.main.async {
                self?.show360ConnectedPopup()
            }
        }
    }
    
    private func presentPolar360FTU() {
        let host = FTUHostingController { [weak self] cfg in
            self?.runFTU(config: cfg)
        }

        host.modalPresentationStyle = .formSheet
        present(host, animated: true)
    }
    
    private func runFTU(config: PolarFirstTimeUseConfig) {

        statusLabel.text = "Sending setup…"

        viewModel.onFtuProgress = { [weak self] msg in
            self?.statusLabel.text = msg
        }

        viewModel.onFtuCompleted = { [weak self] in
            guard let self else { return }
            self.statusLabel.text = "Setup complete"

            DispatchQueue.main.async {
                self.show360ConnectedPopup()
            }
        }

        viewModel.onFtuError = { [weak self] err in
            self?.showAlert(message: err)
        }

        viewModel.startFirstTimeUse(config: config, restartAfter: false)
    }

    // MARK: - Helpers

    /// Extract a numeric percent from a detail string like "progress=37%" or "37%".
    private static func parsePercent(_ details: String) -> Int? {
        // Fast path: find the first number followed by %
        if let range = details.range(of: #"\d{1,3}(?=%)"#, options: .regularExpression) {
            let num = details[range]
            return Int(num)
        }
        return nil
    }


    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.discoveredDevices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath) as! DeviceCell
        let device = viewModel.discoveredDevices[indexPath.row]
        cell.lblDeviceNmae.text = "\(device.name): \(device.id)"
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel.connect(at: indexPath.row)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - UI Helpers
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

extension PolarConnectionViewController: FTUSetupViewControllerDelegate {
    func ftuSetupViewControllerDidCancel(_ vc: FTUSetupViewController) {
        dismiss(animated: true)
    }

    func ftuSetupViewController(_ vc: FTUSetupViewController, didFinishWith form: FTUFormData) {
        vc.dismiss(animated: true,completion: {
            // 1) Health permissions (optional)
            HealthKitService.shared.requestAuthorization(completion: { _, _ in })
            
            // 2) Map app enums -> SDK enums
            let sdkTraining: PolarFirstTimeUseConfig.TrainingBackground = {
                switch form.training {
                case .sedentary:   return .occasional     // closest available
                case .casual:      return .regular
                case .regular:     return .frequent
                case .competitive: return .semiPro        // or .pro if you have a “pro” toggle
                }
            }()
            
            let sdkTypicalDay: PolarFirstTimeUseConfig.TypicalDay = {
                switch form.typicalDay {
                case .mostlySitting: return .mostlySitting
                case .mixed:         return .mostlyMoving  // no .mixed in SDK → pick the active side
                case .mostlyMoving:  return .mostlyMoving
                }
            }()
            
            // 3) Build FTU config
            let cfg = PolarFirstTimeUseConfig(
                gender: {
                    switch form.gender {
                    case .male:   return .male
                    case .female: return .female
                    }
                }(),
                birthDate: form.birthDate,
                height: form.heightCm,          // Float (cm)
                weight: form.weightKg,          // Float (kg)
                maxHeartRate: form.computedMaxHR,
                vo2Max: form.vo2Max,
                restingHeartRate: form.restingHR,
                trainingBackground: sdkTraining,
                deviceTime: ISO8601DateFormatter().string(from: Date()),
                typicalDay: sdkTypicalDay,
                sleepGoalMinutes: form.sleepGoalMinutes
            )

        // 4) Progress hooks
        self.viewModel.onFtuProgress = { [weak self] msg in
            DispatchQueue.main.async { self?.statusLabel.text = msg }
        }
        self.viewModel.onFtuCompleted = { [weak self] in
            DispatchQueue.main.async {
                self?.statusLabel.text = "Setup complete ✅"
                vc.dismiss(animated: true) {
                    let breathingVC = UIStoryboard(name: "Main", bundle: nil)
                        .instantiateViewController(withIdentifier: "BreathingViewController") as! BreathingViewController
                    self?.navigationController?.pushViewController(breathingVC, transitionType: .fade)
                }
            }
        }
        self.viewModel.onFtuError = { [weak self] err in
            DispatchQueue.main.async {
                self?.statusLabel.text = "Setup failed"
                self?.showAlert(message: "First-time setup failed: \(err)")
            }
        }

        // 5) Kick FTU (no reboot by default)
        self.viewModel.startFirstTimeUse(config: cfg, restartAfter: false)
        })
    }
}
