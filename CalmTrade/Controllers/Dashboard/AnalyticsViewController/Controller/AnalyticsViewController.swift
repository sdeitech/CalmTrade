//
//  AnalyticsViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 10/11/25.
//

import UIKit
import Combine

final class AnalyticsViewController: UIViewController {

    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var containerView: UIView!

    private let vm = AnalyticsViewModel()
    private var cancellables: Set<AnyCancellable> = []

    private var pageVC: AnalyticsPageViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSegments()
        bindViewModel()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let pvc = segue.destination as? AnalyticsPageViewController {
            self.pageVC = pvc
            pvc.vm = vm
        }
    }

    private func setupSegments() {
        AnalyticsSection.allCases.forEach { section in
            segmentedControl.setTitle(section.title, forSegmentAt: section.rawValue)
        }
        segmentedControl.selectedSegmentIndex = vm.selectedSection.rawValue
    }

    private func bindViewModel() {
        vm.$selectedSection
            .sink { [weak self] section in
                self?.segmentedControl.selectedSegmentIndex = section.rawValue
                self?.pageVC.moveTo(section: section)
            }
            .store(in: &cancellables)
    }

    @IBAction func segmentedChanged(_ sender: UISegmentedControl) {
        let section = vm.sectionFor(index: sender.selectedSegmentIndex)
        vm.selectedSection = section
    }
}

