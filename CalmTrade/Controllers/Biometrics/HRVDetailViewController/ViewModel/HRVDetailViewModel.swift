//
//  HRVDetailViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 02/09/25.
//


import Foundation
import Charts
import HealthKit

// A data structure to pass all necessary UI data from ViewModel to ViewController
struct HRVUIData {
    let chartData: LineChartData
    let averageValue: String
    let dateRange: String
    let xAxisLabels: [String]
}

class HRVDetailViewModel {
    
    enum ChartTimeRange {
        case daily, weekly, monthly
    }
    
    // This closure will be called when the chart data is ready for the UI
    var onDataReady: ((HRVUIData?) -> Void)?
    private let deviceManager = DeviceManager.shared
    private let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    
    /// The main entry point for the ViewController to request data.
    func fetchData(for range: ChartTimeRange) {
        HealthKitManager.shared.requestAuthorization { [weak self] success, error in
            guard success, error == nil else {
                self?.onDataReady?(nil) // Signal that data is unavailable
                return
            }
            
            // If authorized, proceed with fetching data for the selected range.
            switch range {
            case .daily: self?.fetchDailyData()
            case .weekly: self?.fetchWeeklyData()
            case .monthly: self?.fetchMonthlyData()
            }
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchDailyData() {
        let calendar = Calendar.current
        let anchorDate = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: anchorDate, end: Date(), options: .strictStartDate)
        let interval = DateComponents(hour: 1)
        
        deviceManager.fetchStatisticsCollection(for: hrvType, predicate: predicate, options: .discreteAverage, anchorDate: anchorDate, interval: interval) { [weak self] results in
            self?.process(statsCollection: results, range: .daily, anchorDate: anchorDate)
        }
    }
    
    private func fetchWeeklyData() {
        let calendar = Calendar.current
        guard let anchorDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            onDataReady?(nil)
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: anchorDate, end: Date(), options: .strictStartDate)
        let interval = DateComponents(day: 1)
        
        deviceManager.fetchStatisticsCollection(for: hrvType, predicate: predicate, options: .discreteAverage, anchorDate: anchorDate, interval: interval) { [weak self] results in
            self?.process(statsCollection: results, range: .weekly, anchorDate: anchorDate)
        }
    }
    
    private func fetchMonthlyData() {
        let calendar = Calendar.current
        guard let anchorDate = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) else {
            onDataReady?(nil)
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: anchorDate, end: Date(), options: .strictStartDate)
        let interval = DateComponents(weekOfYear: 1)
        
        deviceManager.fetchStatisticsCollection(for: hrvType, predicate: predicate, options: .discreteAverage, anchorDate: anchorDate, interval: interval) { [weak self] results in
            self?.process(statsCollection: results, range: .monthly, anchorDate: anchorDate)
        }
    }
    
    // MARK: - Unified Data Processing
    
    private func process(statsCollection: HKStatisticsCollection?, range: ChartTimeRange, anchorDate: Date) {
        guard let statsCollection = statsCollection else {
            onDataReady?(nil)
            return
        }
        
        var entries: [ChartDataEntry] = []
        var totalValue: Double = 0
        var dataPointCount: Int = 0
        
        let group = DispatchGroup()
        group.enter()
        
        statsCollection.enumerateStatistics(from: anchorDate, to: Date()) { statistics, stop in
            if let averageValue = statistics.averageQuantity()?.doubleValue(for: .secondUnit(with: .milli)) {
                // **THE FIX**: Use the current count of entries as the x-value.
                // This guarantees a sequential index (0, 1, 2...) that maps to the labels array.
                let xValue = Double(entries.count)
                
                entries.append(ChartDataEntry(x: xValue, y: averageValue))
                totalValue += averageValue
                dataPointCount += 1
            }
        }
        group.leave()
        
        group.notify(queue: .main) {
            let average = dataPointCount > 0 ? Int(totalValue / Double(dataPointCount)) : 0
            let (dateRange, xAxisLabels) = self.getLabels(for: range)
            let uiData = self.createUIData(from: entries, average: average, dateRange: dateRange, xAxisLabels: xAxisLabels)
            self.onDataReady?(uiData)
        }
    }
    
    // MARK: - Chart Data Creation & Formatting
    
    private func createUIData(from entries: [ChartDataEntry], average: Int, dateRange: String, xAxisLabels: [String]) -> HRVUIData {
        let dataSet = LineChartDataSet(entries: entries, label: "HRV")
        // Styling the line and circles
        let lineColor = UIColor.init("#B52D0B")//(red: 0.96, green: 0.51, blue: 0.31, alpha: 1.00) // Orange
        dataSet.colors = [lineColor]
        dataSet.lineWidth = 2.0
        dataSet.circleHoleColor = .black
        dataSet.circleColors = [lineColor]
        dataSet.circleHoleRadius = 3.0
        dataSet.circleRadius = 4.5
        
        dataSet.drawValuesEnabled = false
        dataSet.mode = .cubicBezier
        
        return HRVUIData(chartData: LineChartData(dataSet: dataSet), averageValue: "\(average)", dateRange: dateRange, xAxisLabels: xAxisLabels)
    }
    
    // MARK: - Formatting Helpers
    private func getLabels(for range: ChartTimeRange) -> (dateRange: String, xAxisLabels: [String]) {
        let now = Date()
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        
        switch range {
        case .daily:
            return ("Today", ["12 AM", "6 AM", "12 PM", "6 PM"])
        case .weekly:
            dateFormatter.dateFormat = "MMM d"
            guard let weekStartDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else { return ("-", []) }
            let weekEndDate = calendar.date(byAdding: .day, value: 6, to: weekStartDate)!
            let rangeString = "\(dateFormatter.string(from: weekStartDate))-\(dateFormatter.string(from: weekEndDate)), \(calendar.component(.year, from: now))"
            return (rangeString, ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
        case .monthly:
            dateFormatter.dateFormat = "MMMM yyyy"
            return (dateFormatter.string(from: now), ["Week 1", "Week 2", "Week 3", "Week 4"])
        }
    }
}

