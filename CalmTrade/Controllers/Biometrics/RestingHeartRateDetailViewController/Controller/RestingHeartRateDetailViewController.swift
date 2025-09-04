//
//  RestingHeartRateDetailViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 02/09/25.
//


import UIKit
import Charts

class RestingHeartRateDetailViewController: BaseViewController {

    // MARK: - Outlets
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var lblAverageValue: UILabel!
    @IBOutlet weak var lblDateRange: UILabel!
    @IBOutlet weak var lineChartView: LineChartView!
    
    // MARK: - Properties
    private let viewModel = RestingHeartRateDetailViewModel()
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSegmentedControl()
        setupChartStyle()
        setupViewModelBindings()
        
        // Fetch initial data for the default selected segment (Weekly)
        viewModel.fetchData(for: .weekly)
    }
    
    // MARK: - Setup
    private func setupViewModelBindings() {
        viewModel.onDataReady = { [weak self] uiData in
            guard let self = self, let data = uiData else {
                self?.lineChartView.data = nil
                self?.lblAverageValue.text = "--"
                self?.lblDateRange.text = "No Data Available"
                return
            }
            
            self.lblAverageValue.text = data.averageValue
            self.lblDateRange.text = data.dateRange
            self.lineChartView.data = data.chartData
            self.updateXAxis(with: data.xAxisLabels)
        }
    }
    
    private func setupSegmentedControl() {
        let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        segmentedControl.setTitleTextAttributes(textAttributes, for: .normal)
        segmentedControl.setTitleTextAttributes(textAttributes, for: .selected)
    }

    @IBAction func segmentedControlChanged(_ sender: UISegmentedControl) {
        let range: RestingHeartRateDetailViewModel.ChartTimeRange
        switch sender.selectedSegmentIndex {
        case 0: range = .daily
        case 1: range = .weekly
        case 2: range = .monthly
        default: return
        }
        viewModel.fetchData(for: range)
    }

    // MARK: - Chart Styling
    private func setupChartStyle() {
        lineChartView.backgroundColor = .black
        lineChartView.legend.enabled = false
        lineChartView.leftAxis.enabled = false
        
        let yAxis = lineChartView.rightAxis
        yAxis.enabled = true
        yAxis.labelTextColor = .gray
        yAxis.axisLineColor = .darkGray
        yAxis.gridColor = UIColor.darkGray.withAlphaComponent(0.5)
        yAxis.gridLineDashLengths = [4, 4]
        
        // Adjust the Y-axis scale to be appropriate for Resting Heart Rate
        yAxis.axisMinimum = 40
        yAxis.axisMaximum = 90
        
        let xAxis = lineChartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = .gray
        xAxis.axisLineColor = .darkGray
        xAxis.drawGridLinesEnabled = false
        xAxis.granularity = 1
    }
    
    private func updateXAxis(with labels: [String]) {
        let xAxis = lineChartView.xAxis
        xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        xAxis.setLabelCount(labels.count, force: false)
    }
    
    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }
}
