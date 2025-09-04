//
//  HRVDetailViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 02/09/25.
//


import UIKit
import Charts

class HRVDetailViewController: BaseViewController {
    
    // MARK: - Outlets
    
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var lblAverageValue: UILabel!
    @IBOutlet weak var lblDateRange: UILabel!
    @IBOutlet weak var hrvLineChartView: LineChartView!
    
    // MARK: - Properties
    private let viewModel = HRVDetailViewModel()
    
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupChartStyle()
        setupViewModelBindings()
        setupSegmentedControl()
        
        // Start the data fetch
        viewModel.fetchData(for: .weekly)
    }
    
    // MARK: - Setup
    private func setupViewModelBindings() {
        viewModel.onDataReady = { [weak self] uiData in
            // This block is called by the ViewModel when new data is ready.
            // It updates all relevant UI components.
            self?.lblAverageValue.text = uiData?.averageValue
            self?.lblDateRange.text = uiData?.dateRange
            self?.hrvLineChartView.data = uiData?.chartData
            self?.updateXAxis(with: uiData?.xAxisLabels ?? [])
        }
    }
    
    private func setupSegmentedControl() {
        let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        segmentedControl.setTitleTextAttributes(textAttributes, for: .normal)
        segmentedControl.setTitleTextAttributes(textAttributes, for: .selected)
    }
    
    private func setupChartStyle() {
        // --- General Styling ---
        hrvLineChartView.backgroundColor = .black
        hrvLineChartView.legend.enabled = false
        hrvLineChartView.leftAxis.enabled = false // Y-Axis on the left is disabled
        
        hrvLineChartView.legend.form = .square
        
//        hrvLineChartView.legend.
        
        // --- Y-Axis (Right/Trailing) Styling ---
        let yAxis = hrvLineChartView.rightAxis
        yAxis.enabled = true
        yAxis.labelPosition = .outsideChart
        yAxis.labelTextColor = .init("#7D7779")
        yAxis.axisLineColor = .init("#313131")
        yAxis.gridColor = UIColor.init("#2D2D2D")
        
        yAxis.gridLineDashLengths = [2, 2]
        
        yAxis.axisMinimum = 0
        yAxis.axisMaximum = 300
        yAxis.granularity = 100
        
        // --- X-Axis (Bottom) Styling ---
        // General styling is set here. The specific labels are set dynamically.
        let xAxis = hrvLineChartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = .init("#7D7779")
        xAxis.axisLineColor = .init("#313131")
        xAxis.drawGridLinesEnabled = false
        xAxis.granularity = 1
    }
    
    private func updateXAxis(with labels: [String]) {
        let xAxis = hrvLineChartView.xAxis
        xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        
        // Adjust label count based on the number of labels to prevent crowding
        xAxis.setLabelCount(labels.count, force: false)
    }
    
    // MARK: - Actions
    
    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController(transitionType: .fade, duration: 0.003)
    }
    
    @IBAction func segmentedControlChanged(_ sender: UISegmentedControl) {
            let selectedRange: HRVDetailViewModel.ChartTimeRange
            switch sender.selectedSegmentIndex {
            case 0:
                selectedRange = .daily
            case 1:
                selectedRange = .weekly
            case 2:
                selectedRange = .monthly
            default:
                return
            }
            viewModel.fetchData(for: selectedRange)
        }
}

