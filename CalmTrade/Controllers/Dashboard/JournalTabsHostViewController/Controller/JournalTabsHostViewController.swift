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
    
    private var pendingDate: Date?
    
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
    
    @IBAction func calendarTapped(_ sender: UIButton) {

        let pickerVC = UIViewController()
        pickerVC.preferredContentSize = CGSize(width: 320, height: 320)

        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.locale = .current
        picker.date = vm.selectedDate

        pendingDate = vm.selectedDate

        picker.addTarget(
            self,
            action: #selector(dateChanged(_:)),
            for: .valueChanged
        )

        // Toolbar
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneTapped))

        toolbar.setItems([flex, done], animated: false)

        pickerVC.view.addSubview(toolbar)
        pickerVC.view.addSubview(picker)

        picker.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: pickerVC.view.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: pickerVC.view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: pickerVC.view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 50),

            picker.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            picker.leadingAnchor.constraint(equalTo: pickerVC.view.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: pickerVC.view.trailingAnchor),
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
        pendingDate = sender.date
    }
    
    @objc private func doneTapped() {
        guard let date = pendingDate else { return }

        vm.selectedDate = date
        vm.update(date: date)
        updateAllPages(with: date)

        dismiss(animated: true)
    }

}

extension JournalTabsHostViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
