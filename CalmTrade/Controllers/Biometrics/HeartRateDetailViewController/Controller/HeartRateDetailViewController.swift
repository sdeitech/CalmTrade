//
//  HeartRateDetailViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 02/09/25.
//


import UIKit
import Charts

class HeartRateDetailViewController: BaseViewController {

    // MARK: - Outlets
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var lblHeartRateRange: UILabel!
    @IBOutlet weak var lblDateRange: UILabel!
    @IBOutlet weak var heartRateBarChartView: CandleStickChartView!
    
    @IBOutlet weak var lblLatestTime: UILabel!
    @IBOutlet weak var lblLatestValue: UILabel!
    
    // Outlets for the first highlight card
    @IBOutlet weak var lblHighlightTitle: UILabel!
    @IBOutlet weak var lblHighlightDescription: UILabel!
    
    // MARK: - Properties
    private let viewModel = HeartRateDetailViewModel()
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSegmentedControl()
        setupChartStyle()
        setupViewModelBindings()
        
        // Fetch initial data for the default selected segment (Daily)
        viewModel.fetchData(for: .daily)
    }
    
    // MARK: - Setup
    private func setupViewModelBindings() {
        viewModel.onDataReady = { [weak self] uiData in
            guard let self = self, let data = uiData else {
                // Handle no data state
                self?.lblHeartRateRange.text = "--"
                self?.heartRateBarChartView.data = nil
                return
            }
            
            self.lblHeartRateRange.text = data.range
            self.lblDateRange.text = data.dateRange
            self.lblLatestTime.text = "Latest : \(data.latestTime)"
            self.lblLatestValue.text = data.latestValue
            self.heartRateBarChartView.data = data.chartData
            self.updateXAxis(with: data.xAxisLabels)
            
            // Update highlights
            if let firstHighlight = data.highlights.first {
//                self.lblHighlightTitle.text = firstHighlight.title
//                self.lblHighlightDescription.text = firstHighlight.description
            }
        }
    }
    
    private func setupSegmentedControl() {
        let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        segmentedControl.setTitleTextAttributes(textAttributes, for: .normal)
        segmentedControl.setTitleTextAttributes(textAttributes, for: .selected)
    }
    
    // MARK: - Actions
    @IBAction func segmentedControlChanged(_ sender: UISegmentedControl) {
        let selectedRange: HeartRateDetailViewModel.ChartTimeRange
        switch sender.selectedSegmentIndex {
        case 0: selectedRange = .daily
        case 1: selectedRange = .weekly
        case 2: selectedRange = .monthly
        default: return
        }
        viewModel.fetchData(for: selectedRange)
    }
    
    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController(transitionType: .fade)
    }

    // MARK: - Chart Styling
    private func setupChartStyle() {
        heartRateBarChartView.backgroundColor = .black
        heartRateBarChartView.legend.enabled = false
        heartRateBarChartView.leftAxis.enabled = false
        
        let yAxis = heartRateBarChartView.rightAxis
        yAxis.enabled = true
        yAxis.labelTextColor = .gray
        yAxis.axisLineColor = .darkGray
        yAxis.gridColor = .clear
        yAxis.axisMinimum = 0
        yAxis.axisMaximum = 150
        yAxis.granularity = 50
        
        let xAxis = heartRateBarChartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = .gray
        xAxis.axisLineColor = .darkGray
        xAxis.gridColor = .darkGray
        xAxis.granularity = 1
    }
    
    private func updateXAxis(with labels: [String]) {
        let xAxis = heartRateBarChartView.xAxis
        xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        xAxis.setLabelCount(labels.count, force: true)
    }
}
