//
//  StepsDetailViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/09/25.
//


import UIKit
import Charts

class StepsDetailViewController: BaseViewController {

    // MARK: - Outlets
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var lblAverageValue: UILabel!
    @IBOutlet weak var lblDateRange: UILabel!
    @IBOutlet weak var barChartView: BarChartView!
    
    @IBOutlet weak var lblTrendTitle: UILabel!
    @IBOutlet weak var lblTrendDescription: UILabel!

    // MARK: - Properties
    private let viewModel = StepsDetailViewModel()
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSegmentedControl()
        setupChartStyle()
        setupViewModelBindings()
        
        viewModel.fetchData(for: .weekly) // Default to weekly view
    }
    
    // MARK: - Setup
    private func setupViewModelBindings() {
        viewModel.onDataReady = { [weak self] uiData in
            guard let self = self, let data = uiData else {
                self?.barChartView.data = nil
                self?.lblAverageValue.text = "0"
                self?.lblDateRange.text = "No Data Available"
                return
            }
            
            self.lblAverageValue.text = data.averageValue
            self.lblDateRange.text = data.dateRange
            self.barChartView.data = data.chartData
            self.updateXAxis(with: data.xAxisLabels)
            
            if let firstTrend = data.trends.first {
                self.lblTrendTitle.text = firstTrend.title
                self.lblTrendDescription.text = firstTrend.description
            }
        }
    }
    
    private func setupSegmentedControl() {
        let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        segmentedControl.setTitleTextAttributes(textAttributes, for: .normal)
        segmentedControl.setTitleTextAttributes(textAttributes, for: .selected)
    }

    @IBAction func segmentedControlChanged(_ sender: UISegmentedControl) {
        let range: StepsDetailViewModel.ChartTimeRange
        switch sender.selectedSegmentIndex {
        case 0: range = .daily
        case 1: range = .weekly
        case 2: range = .monthly
        default: return
        }
        viewModel.fetchData(for: range)
    }
    
    @IBAction func btnBackTapped(_ sender: UIButton) {
        self.navigationController?.popViewController()
    }

    // MARK: - Chart Styling
    private func setupChartStyle() {
        barChartView.backgroundColor = .black
        barChartView.legend.enabled = false
        barChartView.leftAxis.enabled = false
        
        let yAxis = barChartView.rightAxis
        yAxis.enabled = true
        yAxis.labelTextColor = .gray
        yAxis.axisLineColor = .clear // No Y-axis line in the design
        yAxis.gridColor = .darkGray
        yAxis.gridLineDashLengths = [4, 4]
        yAxis.axisMinimum = 0
        // Custom Y-axis labels like "5k", "10k"
        yAxis.valueFormatter = YAxisValueFormatter()
        
        let xAxis = barChartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = .gray
        xAxis.axisLineColor = .darkGray
        xAxis.drawGridLinesEnabled = false // No vertical grid lines
        xAxis.granularity = 1
    }
    
    private func updateXAxis(with labels: [String]) {
        let xAxis = barChartView.xAxis
        xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        xAxis.setLabelCount(labels.count, force: true)
    }
}

// Custom formatter for the Y-axis to show "5k", "10k", etc.
class YAxisValueFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        if value == 0 { return "0" }
        if value < 1000 { return "\(Int(value))" }
        return "\(Int(value / 1000))k"
    }
}
