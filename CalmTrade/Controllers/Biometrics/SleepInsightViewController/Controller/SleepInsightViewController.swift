//
//  SleepInsightViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/09/25.
//


import UIKit
import Charts

class SleepInsightViewController: BaseViewController, UICalendarSelectionSingleDateDelegate, UIPopoverPresentationControllerDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var lblTimeAsleep: UILabel!
    @IBOutlet weak var lblSleepDate: UILabel!
    @IBOutlet weak var sleepChartView: BarChartView!
    @IBOutlet weak var calendarButton: UIButton! // Connect this to your calendar icon button
    
    // MARK: - Properties
    private let viewModel = SleepInsightViewModel()
    private var selectedDate: Date = Date()
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupChartStyle()
        setupViewModelBindings()
        
        // Fetch data for the current date initially
        viewModel.fetchData(for: selectedDate)
    }
    
    // MARK: - Setup
    private func setupViewModelBindings() {
        viewModel.onDataReady = { [weak self] uiData in
            guard let self = self, let data = uiData else {
                self?.lblTimeAsleep.text = "No Sleep Data"
                self?.sleepChartView.data = nil
                return
            }
            
            self.lblTimeAsleep.attributedText = data.timeAsleepAttributedText
            self.lblSleepDate.text = data.sleepDate
            self.sleepChartView.data = data.chartData
            self.updateXAxis(with: data.xAxisLabels, at: data.xAxisValues)
        }
    }
    
    // MARK: - Actions
    @IBAction func calendarButtonTapped(_ sender: UIButton) {
        let calendarVC = UIViewController()
        
        let calendarView = UICalendarView()
        calendarView.calendar = .current
        calendarView.locale = .current
        let selection = UICalendarSelectionSingleDate(delegate: self)
        selection.selectedDate = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        calendarView.selectionBehavior = selection
        
        calendarVC.view = calendarView
        
        // --- Popover Configuration ---
        calendarVC.modalPresentationStyle = .popover
        calendarVC.preferredContentSize = CGSize(width: 320, height: 300)
        
        guard let popover = calendarVC.popoverPresentationController else { return }
        popover.sourceView = sender
        popover.permittedArrowDirections = .up
        
        // **THE KEY FIX**: Set the delegate to self.
        popover.delegate = self
        
        present(calendarVC, animated: true)
    }
    
    @IBAction func btnbackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }
    
    // MARK: - UICalendarSelectionSingleDateDelegate
    func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
        guard let date = dateComponents?.date else { return }
        self.selectedDate = date
        
        // Dismiss the popover and fetch new data
        self.presentedViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.viewModel.fetchData(for: date)
        })
    }
    
    // MARK: - Chart Styling
    private func setupChartStyle() {
        sleepChartView.backgroundColor = .black
        sleepChartView.legend.enabled = false
        sleepChartView.rightAxis.enabled = false
        
        let yAxis = sleepChartView.leftAxis
        yAxis.labelTextColor = .gray
        yAxis.axisLineColor = .clear
        yAxis.gridColor = .darkGray
        let sleepStages = ["", "Deep", "Core", "REM", "Awake"]
        yAxis.valueFormatter = IndexAxisValueFormatter(values: sleepStages)
        yAxis.setLabelCount(sleepStages.count, force: true)
        yAxis.axisMinimum = 0
        yAxis.axisMaximum = Double(sleepStages.count)
        
        let xAxis = sleepChartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = .gray
        xAxis.axisLineColor = .darkGray
        xAxis.gridColor = .darkGray
    }
    
    /// Updates the X-Axis to show custom time labels at specific positions.
    private func updateXAxis(with labels: [String], at values: [Double]) {
        let xAxis = sleepChartView.xAxis
        xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        
        // This tells the chart to only draw labels at the specific time values we calculated.
        xAxis.setLabelCount(labels.count, force: true)
        xAxis.axisMinLabels = labels.count
        
        // The customAxisMin/Max and entries are needed for custom label positioning
        var customAxisEntries: [Double] = []
        for value in values {
            customAxisEntries.append(value)
        }
        xAxis.axisMinLabels = labels.count
        xAxis.entries = customAxisEntries
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
