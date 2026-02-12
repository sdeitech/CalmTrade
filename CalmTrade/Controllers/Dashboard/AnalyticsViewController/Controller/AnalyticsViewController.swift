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
            let access = FeatureGate.shared.access(for: FeatureKey.tradeAnalyticsStats)
            var title = section.title
            if section.title != AnalyticsSection.topAnalytics.title {
                switch access {
                case .allowed:
                    break
                case .locked:
                    title = title + "🔒"
                }
            }
            
            segmentedControl.setTitle(title, forSegmentAt: section.rawValue)
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
        if sender.selectedSegmentIndex != 0 {
            let access = FeatureGate.shared.access(for: FeatureKey.tradeAnalyticsStats)
            switch access {
            case .allowed:
                let section = vm.sectionFor(index: sender.selectedSegmentIndex)
                vm.selectedSection = section
            case .locked:
                FeatureGate.shared.presentUpgradeSheet(for: FeatureKey.tradeAnalyticsStats, from: self)
                sender.selectedSegmentIndex = 0
            }
        } else {
            let section = vm.sectionFor(index: sender.selectedSegmentIndex)
            vm.selectedSection = section
        }
    }
    
    @IBAction func importButtonTapped(_ sender: UIButton) {
        let importTradesVC = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil).instantiateViewController(withIdentifier: "ImportTradesViewController") as! ImportTradesViewController
        self.navigationController?.pushViewController(importTradesVC)
    }
    
    @IBAction func didTapFlowerIcon(_ sender: Any) {
        let deviceManagerVC = UIStoryboard(name: Constants.Storyboard.Devices, bundle: nil).instantiateViewController(withIdentifier: "DeviceManagementViewController") as! DeviceManagementViewController
        self.navigationController?.pushViewController(deviceManagerVC)
    }
    
    @IBAction func didTapProfileIcon(_ sender: Any) {
        self.navigationController?.pushViewController(UIStoryboard(name: Constants.Storyboard.ProfileHost, bundle: nil).instantiateViewController(withIdentifier: "ProfileTabsHostViewController") as! ProfileTabsHostViewController,transitionType: .fade)
    }
    
    @IBAction func didTapCalendarIcon(_ sender: Any) {
        let calendarVC = UIStoryboard(name: Constants.Storyboard.Home, bundle: nil).instantiateViewController(withIdentifier: "CalendarViewController") as! CalendarViewController
        self.navigationController?.pushViewController(calendarVC)
    }
}

