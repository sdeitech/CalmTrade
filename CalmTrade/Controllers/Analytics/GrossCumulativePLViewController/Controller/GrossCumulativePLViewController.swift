//
//  GrossCumulativePLViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 09/12/25.
//


import UIKit
import Combine
import SwiftUI
import KRProgressHUD

final class GrossCumulativePLViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var chartContainer: UIView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!

    private let vm = GrossCumulativePLViewModel()
    private var hosting: UIHostingController<GrossCumulativePLChart>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindVM()
        vm.fetchPL(range: "daily")
    }

    private func setupUI() {
        segmentedControl.removeAllSegments()
        ["Daily", "Weekly", "Monthly", "Yearly"].enumerated().forEach { idx, title in
            segmentedControl.insertSegment(withTitle: title, at: idx, animated: false)
        }
        segmentedControl.selectedSegmentIndex = 0
    }

    private func bindVM() {
        vm.$points
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pts in
                self?.updateChart(points: pts)
            }
            .store(in: &cancellables)

        vm.$loading
            .sink { loading in
                loading ? LoaderManager.shared.show() : LoaderManager.shared.hide()
            }
            .store(in: &cancellables)

        vm.$errorMessage
            .compactMap { $0 }
            .sink { msg in
                print("❌ Error:", msg)
            }
            .store(in: &cancellables)
    }

    private func updateChart(points: [CumulativePLPoint]) {
        let view = GrossCumulativePLChart(items: points)

        if let hosting = hosting {
            hosting.rootView = view
            return
        }

        // FIRST TIME HOSTING ATTACHMENT
        let host = UIHostingController(rootView: view)
        self.hosting = host

        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: chartContainer.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor)
        ])

        host.didMove(toParent: self)
    }

    // MARK: - Segmented Control
    @IBAction func didChangeFilter(_ sender: UISegmentedControl) {
        let selected = sender.titleForSegment(at: sender.selectedSegmentIndex) ?? "Daily"
        let ranged = selected.lowercased()
        vm.fetchPL(range: ranged)
    }
    
    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }
}
