//
//  PolarConnectionViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/09/25.
//


import Foundation

class PolarConnectionViewModel {
    
    // MARK: - Properties
    private let polarManager = PolarManager.shared
    private(set) var discoveredDevices: [ScannedPolarDevice] = []
    
    // MARK: - Bindings
    var onDeviceListUpdated: (() -> Void)?
    var onConnectionSuccess: ((String) -> Void)?
    var onConnectionFailed: ((String) -> Void)?
    var onStateChanged: ((String) -> Void)?
    
    init() {
        setupBindings()
    }
    
    /// Listens for updates from the PolarManager.
    private func setupBindings() {
        polarManager.onDevicesUpdated = { [weak self] devices in
            self?.discoveredDevices = devices
            self?.onDeviceListUpdated?()
        }
        
        polarManager.onConnectionStateChanged = { [weak self] state in
            switch state {
            case .disconnected:
                self?.onStateChanged?("Disconnected")
            case .connecting:
                self?.onStateChanged?("Connecting...")
            case .connected(let device):
                self?.onConnectionSuccess?("Connected to \(device.name)")
            }
        }
    }
    
    // MARK: - Public Methods
    
    func startSearch() {
        polarManager.startDeviceSearch()
    }
    
    func stopSearch() {
        polarManager.stopDeviceSearch()
    }
    
    func connect(at index: Int) {
        guard index < discoveredDevices.count else { return }
        let device = discoveredDevices[index]
        polarManager.connect(to: device)
    }
}
