//
//  AnalyticsPageViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 21/11/25.
//


import UIKit

final class AnalyticsPageViewController: UIPageViewController {

    weak var vm: AnalyticsViewModel!
    private var orderedVCs: [UIViewController] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        dataSource = self
        delegate = self

        orderedVCs = vm.viewControllers()

        let index = vm.indexFor(section: vm.selectedSection)
        setViewControllers([orderedVCs[index]], direction: .forward, animated: false)
    }

    func moveTo(section: AnalyticsSection) {
        let targetIndex = vm.indexFor(section: section)
        let currentVC = viewControllers?.first

        guard let currentIndex = orderedVCs.firstIndex(of: currentVC!) else { return }

        let direction: NavigationDirection = targetIndex > currentIndex ? .forward : .reverse

        setViewControllers([orderedVCs[targetIndex]], direction: direction, animated: true)
    }
}

extension AnalyticsPageViewController: UIPageViewControllerDataSource {

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {

        guard let index = orderedVCs.firstIndex(of: viewController),
              index > 0 else { return nil }

        let targetSection = vm.sectionFor(index: index - 1)

        // Gate access here
        if targetSection != .topAnalytics {
            let access = FeatureGate.shared.access(for: FeatureKey.tradeAnalyticsStats)
            switch access {
            case .allowed:
                return orderedVCs[index + 1]
            case .locked(let plan):
                FeatureGate.shared.presentUpgradeSheet(for: FeatureKey.tradeAnalyticsStats,
                                                       from: self)
                return nil
            }
        }

        return orderedVCs[index - 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {

        guard let index = orderedVCs.firstIndex(of: viewController),
              index < orderedVCs.count - 1 else { return nil }

        let targetSection = vm.sectionFor(index: index + 1)

        // Gate access here
        if targetSection != .topAnalytics {
            let access = FeatureGate.shared.access(for: FeatureKey.tradeAnalyticsStats)
            switch access {
            case .allowed:
                return orderedVCs[index + 1]
            case .locked:
                FeatureGate.shared.presentUpgradeSheet(for: FeatureKey.tradeAnalyticsStats,
                                                       from: self)
                return nil
            }
        }

        return orderedVCs[index + 1]
    }
}


extension AnalyticsPageViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {

        guard completed,
              let currentVC = pageViewController.viewControllers?.first,
              let index = orderedVCs.firstIndex(of: currentVC)
        else { return }

        vm.selectedSection = vm.sectionFor(index: index)
    }
}
