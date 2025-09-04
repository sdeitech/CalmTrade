//
//  StepsDetailViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/09/25.
//


import Foundation
import Charts
import HealthKit

class StepsDetailViewModel {
    
    enum ChartTimeRange { case daily, weekly, monthly }
    
    var onDataReady: ((StepsUIData?) -> Void)?
    
    private let healthKitManager = HealthKitManager.shared
    private let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    
    func fetchData(for range: ChartTimeRange) {
        healthKitManager.requestAuthorization { [weak self] success, _ in
            guard success else {
                self?.onDataReady?(nil)
                return
            }
            self?.fetchStepsData(for: range)
        }
    }
    
    private func fetchStepsData(for range: ChartTimeRange) {
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
        
        healthKitManager.fetchStatisticsCollection(for: stepCountType,
                                                predicate: predicate,
                                                options: .cumulativeSum,
                                                anchorDate: anchorDate,
                                                interval: interval) { [weak self] results in
            self?.process(statsCollection: results, range: range, anchorDate: anchorDate)
        }
    }
    
    private func process(statsCollection: HKStatisticsCollection?, range: ChartTimeRange, anchorDate: Date) {
        guard let statsCollection = statsCollection else {
            onDataReady?(nil)
            return
        }
        
        var entries: [BarChartDataEntry] = []
        var totalSteps: Double = 0
        
        let group = DispatchGroup()
        group.enter()
        
        statsCollection.enumerateStatistics(from: anchorDate, to: Date()) { statistics, _ in
            if let sum = statistics.sumQuantity()?.doubleValue(for: .count()) {
                // **THE FIX**: Use a sequential index for the x-value.
                let xValue = Double(entries.count)
                entries.append(BarChartDataEntry(x: xValue, y: sum))
                totalSteps += sum
            }
        }
        group.leave()
        
        group.notify(queue: .main) {
            let dataPointCount = entries.count
            let average = dataPointCount > 0 ? Int(totalSteps / Double(dataPointCount)) : 0
            let (dateRange, xAxisLabels) = self.getLabels(for: range)
            
            let trends = [Trend(title: "Steps", description: "On average, you took more steps over the past 5 weeks")]
            
            let uiData = self.createUIData(from: entries, average: average, dateRange: dateRange, xAxisLabels: xAxisLabels, trends: trends)
            self.onDataReady?(uiData)
        }
    }

    private func createUIData(from entries: [BarChartDataEntry], average: Int, dateRange: String, xAxisLabels: [String], trends: [Trend]) -> StepsUIData {
        let dataSet = BarChartDataSet(entries: entries, label: "Steps")
        
        dataSet.colors = [UIColor(red: 0.85, green: 0.45, blue: 0.22, alpha: 1.00)] // Burnt Orange
        dataSet.drawValuesEnabled = false
        
        let chartData = BarChartData(dataSet: dataSet)
        chartData.barWidth = 0.6
        
        return StepsUIData(chartData: chartData, averageValue: formatSteps(average), dateRange: dateRange, xAxisLabels: xAxisLabels, trends: trends)
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
    
    private func formatSteps(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "0"
    }
}

