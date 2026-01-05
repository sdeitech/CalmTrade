//
//  GrossDailyPnLViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 01/12/25.
//


import UIKit
import Combine
import SwiftUI

final class GrossDailyPnLViewController: UIViewController {

    @IBOutlet weak var graphContainer: UIView!
    @IBOutlet weak var segmentControl: UISegmentedControl!

    private let viewModel = GrossDailyPnLViewModel()
    private var cancellables = Set<AnyCancellable>()

    private var hostingController: UIHostingController<GrossDailyPnLChart>?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
        segmentControl.selectedSegmentIndex = 0
        fetchForSelectedRange()
    }

    // MARK: - Bindings
    private func setupBindings() {

        viewModel.$bars
            .receive(on: RunLoop.main)
            .sink { [weak self] bars in
                self?.updateChart(with: bars)
            }
            .store(in: &cancellables)

        viewModel.$errorMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] msg in
                guard let msg else { return }
                self?.showError(msg)
            }
            .store(in: &cancellables)
    }

    private func fetchForSelectedRange() {
        let idx = segmentControl.selectedSegmentIndex

        let range: String
        switch idx {
        case 0: range = "daily"
        case 1: range = "weekly"
        case 2: range = "monthly"
        case 3: range = "yearly"
        default: range = "yearly"
        }

        viewModel.fetch(range: range)
    }

    // MARK: - Chart Rendering
    private func updateChart(with bars: [DailyPnLBar]) {

        let chart = GrossDailyPnLChart(items: bars)

        if hostingController == nil {
            let host = UIHostingController(rootView: chart)
            hostingController = host

            addChild(host)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            graphContainer.addSubview(host.view)

            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: graphContainer.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: graphContainer.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: graphContainer.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: graphContainer.bottomAnchor)
            ])

            host.didMove(toParent: self)
        } else {
            hostingController?.rootView = chart
        }
    }

    // MARK: - Error Alert
    private func showError(_ msg: String) {
        let a = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
    
    //MARK: - Actions
    @IBAction func backButtonTapped(_ sender: Any) {
        navigationController?.popViewController()
    }
    
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        fetchForSelectedRange()
    }
}
