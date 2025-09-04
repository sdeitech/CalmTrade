//
//  AddSleepDataViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/09/25.
//


import Foundation
import HealthKit
import UIKit

class AddSleepDataViewModel {
    
    // MARK: - Properties
    var startTime: Date = Calendar.current.date(bySettingHour: 22, minute: 30, second: 0, of: Date())!
    var endTime: Date = Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: Date())!
    
    var sleepDate: Date = Date()
    
    private let healthKitManager = HealthKitManager.shared
    
    // MARK: - Computed Properties
    var totalSleepTimeString: NSAttributedString {
        let interval = endTime.timeIntervalSince(startTime)
        // Handle overnight calculation
        let duration = interval > 0 ? interval : interval + (24 * 3600)
        
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        // Create the attributed string for the UI
        let boldFont = UIFont.boldSystemFont(ofSize: 48)
        let regularFont = UIFont.systemFont(ofSize: 24)
        
        let attributedString = NSMutableAttributedString()
        attributedString.append(NSAttributedString(string: "\(hours)", attributes: [.font: boldFont]))
        attributedString.append(NSAttributedString(string: " hr ", attributes: [.font: regularFont]))
        attributedString.append(NSAttributedString(string: "\(minutes)", attributes: [.font: regularFont]))
        attributedString.append(NSAttributedString(string: " min", attributes: [.font: regularFont]))
        return attributedString
    }
    
    // MARK: - Public Methods
    
    /// Saves the selected sleep time range to HealthKit.
    func saveSleepData(completion: @escaping (Bool, Error?) -> Void) {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        
        // The 'sleepDate' from the calendar represents the day the user woke up.
        var finalEndDate = calendar.date(bySettingHour: endComponents.hour!, minute: endComponents.minute!, second: 0, of: sleepDate)!
        var finalStartDate = calendar.date(bySettingHour: startComponents.hour!, minute: startComponents.minute!, second: 0, of: sleepDate)!
        
        // **Crucial Logic**: If the start time is "later" than the end time (e.g., 10 PM vs 6 AM),
        // it means the sleep started on the day *before* the selected wake-up date.
        if finalStartDate > finalEndDate {
            finalStartDate = calendar.date(byAdding: .day, value: -1, to: finalStartDate)!
        }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let sleepSample = HKCategorySample(type: sleepType,
                                           value: HKCategoryValueSleepAnalysis.asleep.rawValue,
                                           start: finalStartDate,
                                           end: finalEndDate)
        
        healthKitManager.healthStore.save(sleepSample, withCompletion: completion)
    }
}
