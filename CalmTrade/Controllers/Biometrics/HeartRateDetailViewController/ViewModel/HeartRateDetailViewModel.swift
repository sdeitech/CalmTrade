//
//  HeartRateDetailViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 02/09/25.
//


import Foundation
import Charts
import HealthKit

class HeartRateDetailViewModel {
    
    enum ChartTimeRange { case daily, weekly, monthly }
    
    var onDataReady: ((HeartRateUIData?) -> Void)?
    
    private let healthKitManager = HealthKitManager.shared
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    
    func fetchData(for range: ChartTimeRange) {
        healthKitManager.requestAuthorization { [weak self] success, _ in
            guard success else { self?.onDataReady?(nil); return }
            self?.fetchHeartRateData(for: range)
        }
    }
    
    private func fetchHeartRateData(for range: ChartTimeRange) {
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
        let options: HKStatisticsOptions = [.discreteMin, .discreteMax]
        
        healthKitManager.fetchStatisticsCollection(for: heartRateType, predicate: predicate, options: options, anchorDate: anchorDate, interval: interval) { [weak self] results in
            self?.process(statsCollection: results, range: range, anchorDate: anchorDate)
        }
    }
    
    private func process(statsCollection: HKStatisticsCollection?, range: ChartTimeRange, anchorDate: Date) {
        guard let statsCollection = statsCollection else {
            onDataReady?(nil)
            return
        }
        
        var entries: [CandleChartDataEntry] = []
        var allValues: [Double] = []
        
        let group = DispatchGroup()
        group.enter()
        
        statsCollection.enumerateStatistics(from: anchorDate, to: Date()) { statistics, stop in
            let min = statistics.minimumQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))
            let max = statistics.maximumQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))
            
            if let min = min, let max = max, min > 0, max > 0 {
                // **THE FIX**: Use a sequential index for the x-value.
                let xValue = Double(entries.count)
                
                entries.append(CandleChartDataEntry(x: xValue, shadowH: max, shadowL: min, open: min, close: max))
                allValues.append(contentsOf: [min, max])
            }
        }
        group.leave()
        
        group.notify(queue: .main) {
            self.fetchHighlightsAndFinalize(entries: entries, allValues: allValues, range: range)
        }
    }
    
    /// This function chains the remaining async calls after the main chart data is processed.
    private func fetchHighlightsAndFinalize(entries: [CandleChartDataEntry], allValues: [Double], range: ChartTimeRange) {
        fetchSleepHeartRateHighlight { [weak self] highlight in
            self?.healthKitManager.fetchMostRecentSample(for: (self?.heartRateType)!) { [weak self] latestSample in
                guard let self = self else { return }
                
                var highlights: [Highlight] = []
                if let highlight = highlight {
                    highlights.append(highlight)
                }

                let (dateRange, xAxisLabels) = self.getLabels(for: range)
                let uiData = self.createUIData(
                    from: entries,
                    allValues: allValues,
                    latestSample: latestSample as? HKQuantitySample,
                    dateRange: dateRange,
                    xAxisLabels: xAxisLabels,
                    highlights: highlights
                )
                self.onDataReady?(uiData)
            }
        }
    }

    private func createUIData(from entries: [CandleChartDataEntry], allValues: [Double], latestSample: HKQuantitySample?, dateRange: String, xAxisLabels: [String], highlights: [Highlight]) -> HeartRateUIData {
        let dataSet = CandleChartDataSet(entries: entries, label: "Heart Rate")
        
        // Styling for the Floating Bar/Capsule Look
        let barColor = UIColor.systemRed
        dataSet.shadowColor = barColor
        dataSet.shadowWidth = 2.5
        dataSet.decreasingColor = barColor // Helps rendering consistency
        dataSet.increasingColor = barColor // Helps rendering consistency
        dataSet.drawValuesEnabled = false
        dataSet.showCandleBar = false
        
        let chartData = CandleChartData(dataSet: dataSet)
        
        let minBPM = Int(allValues.min() ?? 0)
        let maxBPM = Int(allValues.max() ?? 0)
        let latestBPM = Int(latestSample?.quantity.doubleValue(for: .count().unitDivided(by: .minute())) ?? 0)
        
        return HeartRateUIData(
            chartData: chartData,
            range: "\(minBPM)-\(maxBPM)",
            dateRange: dateRange,
            latestTime: formatTime(latestSample?.endDate ?? Date()),
            latestValue: "\(latestBPM)",
            xAxisLabels: xAxisLabels,
            highlights: highlights
        )
    }
    
    // MARK: - Dynamic Highlights
    
    private func fetchSleepHeartRateHighlight(completion: @escaping (Highlight?) -> Void) {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-86400), end: Date(), options: .strictEndDate)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            guard let self = self,
                  let lastSleep = samples?.first(where: { ($0 as? HKCategorySample)?.value == HKCategoryValueSleepAnalysis.asleep.rawValue }) as? HKCategorySample
            else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let hrPredicate = HKQuery.predicateForSamples(withStart: lastSleep.startDate, end: lastSleep.endDate, options: .strictStartDate)
            let hrQuery = HKSampleQuery(sampleType: self.heartRateType, predicate: hrPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, hrSamples, _ in
                guard let samples = hrSamples as? [HKQuantitySample], !samples.isEmpty else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                let bpmUnit = HKUnit.count().unitDivided(by: .minute())
                let rates = samples.map { $0.quantity.doubleValue(for: bpmUnit) }
                let minRate = Int(rates.min() ?? 0)
                let maxRate = Int(rates.max() ?? 0)
                
                let highlight = Highlight(
                    title: "Heart Rate: Sleep",
                    description: "While you were sleeping, your heart rate ranged from \(minRate) to \(maxRate) beats per minute."
                )
                DispatchQueue.main.async { completion(highlight) }
            }
            self.healthKitManager.healthStore.execute(hrQuery)
        }
        healthKitManager.healthStore.execute(query)
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
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
