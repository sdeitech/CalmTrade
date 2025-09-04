//
//  SleepInsightViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/09/25.
//


import UIKit
import Charts
import HealthKit

class SleepInsightViewModel {
    
    // This closure will be called when the UI data is ready.
    var onDataReady: ((SleepUIData?) -> Void)?
    
    private let healthKitManager = HealthKitManager.shared
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    
    /// The main entry point to start fetching and processing sleep data for a specific date.
    func fetchData(for date: Date) {
        healthKitManager.requestAuthorization { [weak self] success, _ in
            guard success else {
                self?.onDataReady?(nil)
                return
            }
            self?.fetchSleepData(for: date)
        }
    }
    
    private func fetchSleepData(for date: Date) {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            guard let self = self, let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                DispatchQueue.main.async { self?.onDataReady?(nil) }
                return
            }
            
            let uiData = self.process(sleepSamples: sleepSamples)
            DispatchQueue.main.async {
                self.onDataReady?(uiData)
            }
        }
        healthKitManager.healthStore.execute(query)
    }
    
    /// Processes the raw sleep samples into a format suitable for the UI.
    private func process(sleepSamples: [HKCategorySample]) -> SleepUIData {
        var chartEntries: [BarChartDataEntry] = []
        var totalSleepTime: TimeInterval = 0
        
        for sample in sleepSamples {
            let yValue = value(for: HKCategoryValueSleepAnalysis(rawValue: sample.value)!)
            // The x-value represents the time of day, as hours from the start of the day.
            let xValue = sample.startDate.hours(from: Calendar.current.startOfDay(for: sample.startDate))
            // The width of the bar represents the duration of the sleep stage.
            let durationHours = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
            
            // We create a bar for each sleep stage sample.
            chartEntries.append(BarChartDataEntry(x: xValue, y: yValue))
            
            if HKCategoryValueSleepAnalysis(rawValue: sample.value) != .awake {
                totalSleepTime += sample.endDate.timeIntervalSince(sample.startDate)
            }
        }
        
        let dataSet = BarChartDataSet(entries: chartEntries, label: "Sleep Stages")
        dataSet.colors = sleepSamples.map { color(for: HKCategoryValueSleepAnalysis(rawValue: $0.value)!) }
        dataSet.drawValuesEnabled = false

        let chartData = BarChartData(dataSet: dataSet)
        // Adjust this width to make the bars appear as a continuous timeline.
        chartData.barWidth = 0.5
        
        let (xAxisLabels, xAxisValues) = generateXAxisLabels(from: sleepSamples)
        
        return SleepUIData(
            chartData: chartData,
            timeAsleepAttributedText: createTimeAsleepString(from: totalSleepTime),
            sleepDate: formatDate(sleepSamples.first!.startDate),
            xAxisLabels: xAxisLabels,
            xAxisValues: xAxisValues
        )
    }
    
    // MARK: - Formatting and Styling Helpers
    
    private func createTimeAsleepString(from timeInterval: TimeInterval) -> NSAttributedString {
        let totalMinutes = Int(timeInterval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        let boldFont = UIFont.boldSystemFont(ofSize: 48)
        let regularFont = UIFont.systemFont(ofSize: 24)
        let lightGrayColor = UIColor.lightGray
        
        let attributedString = NSMutableAttributedString()
        attributedString.append(NSAttributedString(string: "\(hours)", attributes: [.font: boldFont, .foregroundColor: UIColor.white]))
        attributedString.append(NSAttributedString(string: " hr ", attributes: [.font: regularFont, .foregroundColor: lightGrayColor]))
        attributedString.append(NSAttributedString(string: "\(minutes)", attributes: [.font: boldFont, .foregroundColor: UIColor.white]))
        attributedString.append(NSAttributedString(string: " min", attributes: [.font: regularFont, .foregroundColor: lightGrayColor]))
        
        return attributedString
    }
    
    private func generateXAxisLabels(from samples: [HKCategorySample]) -> (labels: [String], values: [Double]) {
        guard let first = samples.first?.startDate, let last = samples.last?.endDate else { return ([], []) }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "h a" // e.g., "10 PM"

        var labels: [String] = []
        var values: [Double] = []
        
        var currentDate = calendar.date(bySettingHour: calendar.component(.hour, from: first), minute: 0, second: 0, of: first)!
        while currentDate <= last {
            labels.append(formatter.string(from: currentDate).uppercased())
            values.append(currentDate.hours(from: calendar.startOfDay(for: currentDate)))
            currentDate = calendar.date(byAdding: .hour, value: 2, to: currentDate)!
        }
        return (labels, values)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func color(for sleepStage: HKCategoryValueSleepAnalysis) -> UIColor {
        switch sleepStage {
        case .awake: return .systemRed
        case .asleepREM: return .systemTeal
        case .asleepCore: return .systemBlue
        case .asleepDeep: return UIColor(red: 0.3, green: 0.3, blue: 0.8, alpha: 1.0)
        default: return .gray
        }
    }
    
    private func value(for sleepStage: HKCategoryValueSleepAnalysis) -> Double {
        switch sleepStage {
        case .asleepDeep: return 1
        case .asleepCore: return 2
        case .asleepREM: return 3
        case .awake: return 4
        default: return 0 // Other 'inBed' states
        }
    }
}

// Helper extension to calculate hours from a start date.
extension Date {
    func hours(from date: Date) -> Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date, to: self)
        let hours = Double(components.hour ?? 0)
        let minutes = Double(components.minute ?? 0) / 60.0
        return hours + minutes
    }
}
