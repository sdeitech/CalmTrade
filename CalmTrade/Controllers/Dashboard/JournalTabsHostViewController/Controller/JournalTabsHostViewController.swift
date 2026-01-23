//
//  JournalTabsHostViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/01/26.
//

import UIKit
import Combine

final class JournalTabsHostViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var containerView: UIView!
    
    @IBOutlet weak var lblDate: UILabel!
    @IBOutlet weak var btnCalendar: UIButton!

    
    // MARK: - ViewModel (Analytics-style)
    private let vm = JournalViewModel()
    
    // MARK: - PageVC
    private var pageVC: JournalPageViewController!
    
    // MARK: - Combine
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSegments()
        bindViewModel()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let pvc = segue.destination as? JournalPageViewController {
            self.pageVC = pvc
            pvc.vm = vm
        }
    }
    
    // MARK: - Setup
    private func setupSegments() {
        JournalSection.allCases.forEach { section in
            segmentedControl.setTitle(section.title, forSegmentAt: section.rawValue)
        }
        segmentedControl.selectedSegmentIndex = vm.selectedSection.rawValue
    }
    
    // MARK: - Bindings
    private func bindViewModel() {
        vm.$selectedSection
            .sink { [weak self] section in
                self?.segmentedControl.selectedSegmentIndex = section.rawValue
                self?.pageVC.moveTo(section: section)
            }
            .store(in: &cancellables)
        
        vm.$selectedDate
            .sink { [weak self] date in
                let f = DateFormatter()
                f.dateStyle = .medium
                self?.lblDate.text = f.string(from: date)
            }
            .store(in: &cancellables)
    }
    
    private func updateAllPages(with date: Date) {

        vm.update(date: date)

        guard let pages = pageVC?.orderedVCs else { return }

        let apiDate = date.toAPIDateString()

        for vc in pages {

            switch vc {

            case let vc as TimelineViewController:
                vc.viewModel.selectedDate = apiDate
                vc.viewModel.fetch()

            case let vc as ExecutionViewController:
                vc.selectedDate = apiDate
                vc.viewModel.load(date: apiDate)

            case let vc as SessionAnalyticsViewController:
                vc.selectedDate = apiDate
                vc.viewModel.fetch(date: apiDate)

            case let vc as NotesViewController:
                vc.selectedDate = date
                vc.fetchNotes()

            default:
                break
            }
        }
    }

    
    // MARK: - Actions
    @IBAction func segmentedChanged(_ sender: UISegmentedControl) {
        let section = vm.sectionFor(index: sender.selectedSegmentIndex)
        vm.selectedSection = section
    }
    
    @IBAction func calendarTapped(_ sender: UIButton) {

        let pickerVC = UIViewController()
        pickerVC.preferredContentSize = CGSize(width: 320, height: 250)

        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.locale = .current
        picker.date = vm.selectedDate

        picker.addTarget(
            self,
            action: #selector(dateChanged(_:)),
            for: .valueChanged
        )

        pickerVC.view.addSubview(picker)
        picker.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: pickerVC.view.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: pickerVC.view.trailingAnchor),
            picker.topAnchor.constraint(equalTo: pickerVC.view.topAnchor),
            picker.bottomAnchor.constraint(equalTo: pickerVC.view.bottomAnchor)
        ])

        pickerVC.modalPresentationStyle = .popover
        if let popover = pickerVC.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
            popover.permittedArrowDirections = .up
            popover.delegate = self
        }

        present(pickerVC, animated: true)
    }
    
    @objc private func dateChanged(_ sender: UIDatePicker) {
        vm.update(date: sender.date)
        updateAllPages(with: sender.date)
    }

}

extension JournalTabsHostViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
