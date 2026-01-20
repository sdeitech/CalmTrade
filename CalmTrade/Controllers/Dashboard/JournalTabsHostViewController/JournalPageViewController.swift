//
//  JournalPageViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/01/26.
//

import UIKit

final class JournalPageViewController: UIPageViewController {

    // MARK: - ViewModel
    weak var vm: JournalViewModel!

    // MARK: - Pages
    private(set) var orderedVCs: [UIViewController] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataSource = self
        delegate = self
        
        orderedVCs = vm.viewControllers()
        
        let index = vm.indexFor(section: vm.selectedSection)
        setViewControllers([orderedVCs[index]], direction: .forward, animated: false)
    }

    // MARK: - External navigation (Segment → Page)
    func moveTo(section: JournalSection) {
        let targetIndex = vm.indexFor(section: section)
        guard let currentVC = viewControllers?.first,
              let currentIndex = orderedVCs.firstIndex(of: currentVC)
        else { return }

        let direction: NavigationDirection =
            targetIndex > currentIndex ? .forward : .reverse

        setViewControllers(
            [orderedVCs[targetIndex]],
            direction: direction,
            animated: true
        )
    }
}


extension JournalPageViewController: UIPageViewControllerDataSource {

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let index = orderedVCs.firstIndex(of: viewController),
              index > 0 else { return nil }
        return orderedVCs[index - 1]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let index = orderedVCs.firstIndex(of: viewController),
              index < orderedVCs.count - 1 else { return nil }
        return orderedVCs[index + 1]
    }
}

extension JournalPageViewController: UIPageViewControllerDelegate {

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let currentVC = pageViewController.viewControllers?.first,
              let index = orderedVCs.firstIndex(of: currentVC)
        else { return }

        vm.selectedSection = vm.sectionFor(index: index)
    }
}

