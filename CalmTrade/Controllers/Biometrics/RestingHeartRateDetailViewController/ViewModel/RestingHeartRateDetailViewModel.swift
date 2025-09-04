//
//  RestingHeartRateDetailViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 02/09/25.
//


import Foundation
import Charts
import HealthKit

class RestingHeartRateDetailViewModel {
    
    enum ChartTimeRange { case daily, weekly, monthly }
    
    var onDataReady: ((RestingHeartRateUIData?) -> Void)?
    
    private let healthKitManager = HealthKitManager.shared
    private let restingHeartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
    
    func fetchData(for range: ChartTimeRange) {
        healthKitManager.requestAuthorization { [weak self] success, _ in
            guard success else {
                self?.onDataReady?(nil)
                return
            }
            self?.fetchDataForRange(range)
        }
    }
    
    private func fetchDataForRange(_ range: ChartTimeRange) {
        let calendar = Calendar.current
        let endDate = Date()
        let anchorDate: Date
        let interval: DateComponents
        
        switch range {
        case .daily:
            anchorDate = calendar.startOfDay(for: endDate)
            interval = DateComponents(hour: 1)
        case .weekly:
            anchorDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: endDate))!
            interval = DateComponents(day: 1)
        case .monthly:
            anchorDate = calendar.date(from: calendar.dateComponents([.year, .month], from: endDate))!
            interval = DateComponents(weekOfYear: 1)
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: anchorDate, end: endDate, options: .strictStartDate)
        
        healthKitManager.fetchStatisticsCollection(for: restingHeartRateType, predicate: predicate, options: .discreteAverage, anchorDate: anchorDate, interval: interval) { [weak self] results in
            self?.process(statsCollection: results, range: range, anchorDate: anchorDate)
        }
    }
    
    private func process(statsCollection: HKStatisticsCollection?, range: ChartTimeRange, anchorDate: Date) {
        guard let statsCollection = statsCollection else {
            onDataReady?(nil)
            return
        }
        
        var entries: [ChartDataEntry] = []
        var totalValue: Double = 0
        var dataPointCount = 0
        
        let group = DispatchGroup()
        group.enter()
        
        statsCollection.enumerateStatistics(from: anchorDate, to: Date()) { statistics, _ in
            if let averageValue = statistics.averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) {
                // **THE FIX**: Use a sequential index for the x-value.
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

    private func createUIData(from entries: [ChartDataEntry], average: Int, dateRange: String, xAxisLabels: [String]) -> RestingHeartRateUIData {
        let dataSet = LineChartDataSet(entries: entries, label: "Resting Heart Rate")
        
        // Style the line and circles to match the design
        let lineColor = UIColor(red: 0.96, green: 0.51, blue: 0.31, alpha: 1.00) // Orange
        dataSet.colors = [lineColor]
        dataSet.lineWidth = 2.0
        dataSet.circleHoleColor = .black
        dataSet.circleColors = [lineColor]
        dataSet.circleHoleRadius = 3.0
        dataSet.circleRadius = 4.5
        dataSet.drawValuesEnabled = false
        dataSet.mode = .cubicBezier
        
        let chartData = LineChartData(dataSet: dataSet)
        
        return RestingHeartRateUIData(chartData: chartData, averageValue: "\(average)", dateRange: dateRange, xAxisLabels: xAxisLabels)
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

