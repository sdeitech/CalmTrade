//
//  LocalTimeZoneViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 30/10/25.
//  Updated for timezone selection callback on 04/11/25.
//

import UIKit

final class LocalTimeZoneViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet private weak var searchBar: UISearchBar!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var btnBack: UIButton!
    
    private let viewModel = LocalTimeZoneViewModel()
    private var selectedZoneID: String?
    var hidesBackButton: Bool = false
    
    // MARK: - Callback to Parent
    var onTimezoneSelected: ((_ zoneID: String, _ friendlyName: String) -> Void)?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        viewModel.loadZones()
        setupKeyboardDismissGesture()
    }
    
    // MARK: - Setup
    private func setupUI() {
        tableView.tableFooterView = UIView()
        searchBar.delegate = self
        
        btnBack.isHidden = hidesBackButton
    }
    
    private func setupBindings() {
        viewModel.onDataReload = { [weak self] in
            self?.tableView.reloadData()
        }
        viewModel.onError = { [weak self] message in
            self?.showAlert(title: "Error", message: message)
        }
        viewModel.onSuccess = { [weak self] message in
            self?.showAlert(title: "Success", message: message)
        }
    }
    
    private func setupKeyboardDismissGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @IBAction func btnBackTapped(_ sender: Any) {
        if presentingViewController != nil {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController()
        }
    }
}

// MARK: - TableView
extension LocalTimeZoneViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.filteredZones.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "LocalTimeZoneCell", for: indexPath) as? LocalTimeZoneCell else {
            return UITableViewCell()
        }
        
        let zone = viewModel.filteredZones[indexPath.row]
        let isSelected = zone.tzid == selectedZoneID
        cell.configure(with: zone, selected: isSelected)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let zone = viewModel.filteredZones[indexPath.row]
        selectedZoneID = zone.tzid
//        viewModel.selectZone(zone)
        
        // ✅ Notify parent if callback is set
        onTimezoneSelected?(zone.tzid, zone.friendlyName)
        
        // ✅ Dismiss or pop depending on how this VC was shown
        if presentingViewController != nil {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController()
        }
    }
}

// MARK: - Search
extension LocalTimeZoneViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        viewModel.search(searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
