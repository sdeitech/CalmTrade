//
//  DeviceManagementViewController.swift
//  CalmTrade
//

import UIKit

final class DeviceManagementViewController: UIViewController {

    // MARK: - IBOutlets (connect these in storyboard)
    @IBOutlet weak var deviceImageView: UIImageView!
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var deviceIdLabel: UILabel!        // NEW
    @IBOutlet weak var firmwareLabel: UILabel!
    @IBOutlet weak var updateLabel: UILabel!
    @IBOutlet weak var lastSyncedLabel: UILabel!
    @IBOutlet weak var chargingLabel: UILabel!

    @IBOutlet weak var batteryNotificationSwitch: UISwitch!
    @IBOutlet weak var wristSegment: UISegmentedControl! // Left / Right

    @IBOutlet weak var syncButton: UIButton!
    @IBOutlet weak var turnOffButton: UIButton!
    @IBOutlet weak var factoryResetButton: UIButton!

    // Optional: page indicator if you want
    @IBOutlet weak var pageControl: UIPageControl?
    
    @IBOutlet weak var storageLabel: UILabel!
    @IBOutlet weak var deviceTimeLabel: UILabel!
    @IBOutlet weak var timezoneStatusLabel: UILabel!
    @IBOutlet weak var timezoneSyncButton: UIButton!


    private let vm = DeviceManagementViewModel()

    // Swipe gestures to “scroll” between devices
    private lazy var swipeLeft  = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe(_:)))
    private lazy var swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe(_:)))

    // MARK: - Firmware UI (ADDED; no storyboard change)
    private lazy var updateTap = UITapGestureRecognizer(target: self, action: #selector(didTapUpdateLabel))
    private var hasShownInlineUpdateHint = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        vm.delegate = self

        swipeLeft.direction = .left
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeLeft)
        view.addGestureRecognizer(swipeRight)

        wristSegment.removeAllSegments()
        wristSegment.insertSegment(withTitle: "Left Wrist",  at: 0, animated: false)
        wristSegment.insertSegment(withTitle: "Right Wrist", at: 1, animated: false)

        // Make "Update" label tappable to start a non-forced update
        updateLabel.isUserInteractionEnabled = true
        updateLabel.addGestureRecognizer(updateTap)

        Task {
            await vm.load()
            Task { await vm.loadStorage() }
            Task { await vm.loadDeviceTime() }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !vm.isFwUpdating {
            PolarManager.shared.refreshSnapshot()
        } else {
            NSLog("[DMVC] skip refreshSnapshot(): update is running")
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        vm.delegate = nil
        swipeLeft.isEnabled = false
        swipeRight.isEnabled = false
    }

    // MARK: - UI Binding
    private func bindUI() {
        guard let d = vm.current else {
            setControlsEnabled(false)
            deviceNameLabel.text = "No device"
            deviceIdLabel.text   = "ID: —"
            firmwareLabel.text   = "Firmware: —"
            updateLabel.text     = "No updates"
            updateLabel.textColor = .secondaryLabel
            lastSyncedLabel.text = "Last synced: —"
            chargingLabel.text   = "—"
            pageControl?.numberOfPages = 0
            pageControl?.currentPage   = 0
            return
        }

        // Title card
        deviceImageView.image = d.image
        deviceNameLabel.text  = d.name
        deviceIdLabel.text    = vm.deviceIdText(d)
        firmwareLabel.text    = vm.firmwareText(d)

        // Update availability + hint to tap (non-forced flow)
        let availability = vm.updateAvailabilityText(d)
        if availability == "Update available" {
            updateLabel.text = "Update available — tap to install"
            updateLabel.textColor = .systemBlue
            // Optional one-time hint toast; safe, not required
            if !hasShownInlineUpdateHint {
                hasShownInlineUpdateHint = true
                // You can show a lightweight hint here if you have a toast system
                // showToast("Firmware update available. Tap the blue text to start.")
            }
        } else {
            updateLabel.text = availability
            updateLabel.textColor = .secondaryLabel
        }

        lastSyncedLabel.text  = vm.lastSyncedText(d)
        chargingLabel.text    = vm.chargingText(d)
        
        // Battery color logic
        if let pct = d.batteryPercent {
            if d.isCharging == true {
                // Charging → green text
                chargingLabel.textColor = .systemGreen
            } else {
                switch pct {
                case ..<20:
                    chargingLabel.textColor = .systemRed       // Low battery
                case 20..<30:
                    chargingLabel.textColor = .systemYellow    // Medium battery
                default:
                    chargingLabel.textColor = .systemGreen     // Good battery
                }
            }
        } else {
            chargingLabel.textColor = .secondaryLabel          // Unknown
        }

        // Switch (always visible; enabled only for supported devices)
        batteryNotificationSwitch.isOn      = d.batteryNotificationEnabled
        batteryNotificationSwitch.isUserInteractionEnabled = d.canToggleBatteryNotifications

        // Wrist segment (keep VISIBLE but disable when unsupported)
        wristSegment.isUserInteractionEnabled = d.canChooseWristPlacement
        wristSegment.isHidden  = false
        if let wrist = d.wrist {
            wristSegment.selectedSegmentIndex = (wrist == .right) ? 1 : 0
        } else {
            wristSegment.selectedSegmentIndex = 0
        }
        
        if let used = vm.storageUsed, let total = vm.storageTotal {
            let usedMB = used / 1024 / 1024
            let totalMB = total / 1024 / 1024
            storageLabel.text = "Used: \(usedMB) MB / \(totalMB) MB"
        } else {
            storageLabel.text = "Storage: —"
        }

        if let time = vm.deviceTime {
            let df = DateFormatter()
            df.dateFormat = "MMM d, h:mm a"
            deviceTimeLabel.text = "\(df.string(from: time))"

            if vm.timezoneMismatch {
                timezoneStatusLabel.text = "Timezone mismatch"
                timezoneStatusLabel.textColor = .systemRed
                timezoneSyncButton.isHidden = false
            } else {
                timezoneStatusLabel.text = "Timezone correct"
                timezoneStatusLabel.textColor = .systemGreen
                timezoneSyncButton.isHidden = true
            }

        } else {
            deviceTimeLabel.text = "—"
            timezoneStatusLabel.text = ""
            timezoneSyncButton.isHidden = true
        }

        let supportsTurnOff = (vm.current != nil) && PolarManager.shared.supportsTurnOff(vm.current!.id.raw)
        let supportsFactory = (vm.current != nil) && PolarManager.shared.supportsFactoryReset(vm.current!.id.raw)

        syncButton.isUserInteractionEnabled         = vm.current?.canSync ?? false
        turnOffButton.isUserInteractionEnabled      = supportsTurnOff
        factoryResetButton.isUserInteractionEnabled = supportsFactory


        // If a firmware update is running, lock down interactions (non-destructive)
        setControlsEnabled(!vm.isFwUpdating)

        // Page count
        pageControl?.numberOfPages = vm.devices.count
        pageControl?.currentPage   = vm.currentIndex
    }

    private func setControlsEnabled(_ enabled: Bool) {
        batteryNotificationSwitch.isUserInteractionEnabled = enabled
        wristSegment.isUserInteractionEnabled              = enabled
        syncButton.isUserInteractionEnabled                = enabled
        turnOffButton.isUserInteractionEnabled             = enabled
        factoryResetButton.isUserInteractionEnabled        = enabled

        // Prevent accidental paging while updating
        swipeLeft.isEnabled  = enabled
        swipeRight.isEnabled = enabled
        pageControl?.isUserInteractionEnabled = enabled
    }

    // MARK: - Gestures
    @objc private func didSwipe(_ g: UISwipeGestureRecognizer) {
        Task { [weak self] in
            guard let self else { return }
            switch g.direction {
            case .left:  await self.vm.goNext()
            case .right: await self.vm.goPrev()
            default: break
            }
        }
    }

    // MARK: - Firmware tap (ADDED)
    @objc private func didTapUpdateLabel() {
        // Only react if update is available and not already updating
        guard vm.isFwAvailable, !vm.isFwUpdating else { return }
        let name = vm.current?.name ?? "device"
        confirm(title: "Update Firmware?",
                message: "A new firmware is available for your \(name). Do you want to install it now?") { [weak self] in
            Task { await self?.vm.startFirmwareUpdate() }
        }
    }

    // MARK: - IBActions
    @IBAction func batterySwitchChanged(_ sender: UISwitch) {
        // UI already shows new state; repo/VM will broadcast to keep it.
        Task { await vm.toggleBatteryNotification(sender.isOn) }
    }

    @IBAction func wristChanged(_ sender: UISegmentedControl) {
        guard sender.selectedSegmentIndex != UISegmentedControl.noSegment else { return }
        let wrist: CTWristPlacement = (sender.selectedSegmentIndex == 1) ? .right : .left
        Task { await vm.setWrist(wrist) }
    }

    @IBAction func syncTapped(_ sender: UIButton) {
        Task { await vm.sync() }
    }

    @IBAction func turnOffTapped(_ sender: UIButton) {
        confirm(title: "Turn Off Device?",
                message: "This will power off your \(vm.current?.name ?? "device").") { [weak self] in
            Task { await self?.vm.powerOff() }
        }
    }

    @IBAction func factoryResetTapped(_ sender: UIButton) {
        confirm(title: "Factory Reset?",
                message: "This will erase all data on the device.") { [weak self] in
            Task { await self?.vm.factoryReset() }
        }
    }
    
    @IBAction func timezoneSyncTapped(_ sender: UIButton) {
        Task { await vm.setDeviceTimeToLocal() }
    }
    
    @IBAction func backTapped(_ sender: UIButton) {
        self.navigationController?.popViewController()
    }
}

// MARK: - DeviceManagementViewModelDelegate
extension DeviceManagementViewController: DeviceManagementViewModelDelegate {
    func vmDidUpdateCurrentDevice(_ vm: DeviceManagementViewModel) {
        bindUI()
    }

    func vmDidStartLongOperation(_ vm: DeviceManagementViewModel, title: String) {
        // show spinner / HUD if you have one
        // Example (pseudo):
        // HUD.show(title)
        // Also reflect the state on the label for clarity
        LocalNotifier.show(title: "Firmware Update", body: title)
    }

    func vmDidEndLongOperation(_ vm: DeviceManagementViewModel, successMessage: String?) {
        // hide spinner / toast success if you want
        // HUD.hide(); if let msg = successMessage { showToast(msg) }
        bindUI() // ensure UI reflects any immediate state changes
    }

    func vmDidError(_ vm: DeviceManagementViewModel, message: String) {
        // hide spinner and present error
        // HUD.hide(); showAlert(title: "Error", message: message)
        bindUI()
    }
}

// MARK: - Small helper
private extension DeviceManagementViewController {
    func confirm(title: String, message: String, onOK: @escaping () -> Void) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        ac.addAction(UIAlertAction(title: "OK", style: .destructive, handler: { _ in onOK() }))
        present(ac, animated: true)
    }
}
