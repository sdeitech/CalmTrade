//
//  AddSleepDataViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/09/25.
//


import UIKit

class AddSleepDataViewController: UIViewController, UICalendarSelectionSingleDateDelegate, UIPopoverPresentationControllerDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var timePickerView: CircularTimePickerView!
    @IBOutlet weak var lblStartTime: UILabel!
    @IBOutlet weak var lblEndTime: UILabel!
    @IBOutlet weak var lblTotalSleepTime: UILabel!
    @IBOutlet weak var saveButton: UIButton!
    
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var calendarButton: UIButton!
    
    // MARK: - Properties
    private let viewModel = AddSleepDataViewModel()
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTimePicker()
        updateUI()
    }
    
    // MARK: - Setup
    private func setupTimePicker() {
        timePickerView.startTime = viewModel.startTime
        timePickerView.endTime = viewModel.endTime
        
        // This closure is called every time the user drags a handle
        timePickerView.onTimeChanged = { [weak self] start, end in
            self?.viewModel.startTime = start
            self?.viewModel.endTime = end
            self?.updateUI()
        }
    }
    
    // MARK: - UI Updates
    private func updateUI() {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        lblStartTime.text = formatter.string(from: viewModel.startTime).lowercased()
        lblEndTime.text = formatter.string(from: viewModel.endTime).lowercased()
        lblTotalSleepTime.attributedText = viewModel.totalSleepTimeString
        
        // Update the date label based on the ViewModel's selected date
        if Calendar.current.isDateInToday(viewModel.sleepDate) {
            dateLabel.text = "Today"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            dateLabel.text = formatter.string(from: viewModel.sleepDate)
        }
    }
    
    // MARK: - Actions
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        viewModel.saveSleepData { [weak self] success, error in
            if success {
                print("Sleep data saved successfully!")
                DispatchQueue.main.async {
                    self?.navigationController?.popViewController(animated: true)
                }
            } else {
                // Show an alert to the user
                print("Error saving sleep data: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    @IBAction func backButtonTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func calendarButtonTapped(_ sender: UIButton) {
        let calendarVC = UIViewController()
        
        let calendarView = UICalendarView()
        calendarView.calendar = .current
        calendarView.locale = .current
        let selection = UICalendarSelectionSingleDate(delegate: self)
        selection.selectedDate = Calendar.current.dateComponents([.year, .month, .day], from: viewModel.sleepDate)
        calendarView.selectionBehavior = selection
        
        calendarVC.view = calendarView
        
        // Configure the popover presentation
        calendarVC.modalPresentationStyle = .popover
        calendarVC.preferredContentSize = CGSize(width: 320, height: 300)
        
        guard let popover = calendarVC.popoverPresentationController else { return }
        popover.sourceView = sender
        popover.permittedArrowDirections = .up
        popover.delegate = self // This is crucial for forcing a popover on iPhone
        
        present(calendarVC, animated: true)
    }
    
    // MARK: - Delegate Methods
    
    // Handles date selection from the calendar
    func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
        guard let date = dateComponents?.date else { return }
        viewModel.sleepDate = date
        
        // Dismiss the popover and update the UI
        presentedViewController?.dismiss(animated: true) { [weak self] in
            self?.updateUI()
        }
    }
    
    // Forces the popover presentation style on all devices
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
