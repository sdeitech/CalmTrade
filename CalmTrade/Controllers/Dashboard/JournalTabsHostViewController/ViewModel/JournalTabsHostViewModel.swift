//
//  JournalViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/01/26.
//

import UIKit
import Combine

final class JournalViewModel {

    @Published var selectedSection: JournalSection = .timeline
    @Published var selectedDate: Date = Date()

    // MARK: - Pages
    func viewControllers() -> [UIViewController] {
        let sb = UIStoryboard(name: Constants.Storyboard.Journal, bundle: nil)
        
        let timeline = sb.instantiateViewController(
            withIdentifier: "TimelineViewController"
        ) as! TimelineViewController
        let vm = TimelineViewModel()
        vm.selectedDate = selectedDate.toAPIDateString()
        timeline.viewModel = vm
        
        let execution = sb.instantiateViewController(
            withIdentifier: "ExecutionViewController"
        ) as! ExecutionViewController
        execution.selectedDate = selectedDate.toAPIDateString()
        
        let analytics = sb.instantiateViewController(
            withIdentifier: "SessionAnalyticsViewController"
        ) as! SessionAnalyticsViewController
        analytics.selectedDate = selectedDate.toAPIDateString()
        
        let notes = sb.instantiateViewController(
            withIdentifier: "NotesViewController"
        ) as! NotesViewController
        notes.selectedDate = selectedDate
        
        return [timeline, execution, analytics, notes]
    }

    // MARK: - Helpers (mirror AnalyticsViewModel)
    func indexFor(section: JournalSection) -> Int {
        section.rawValue
    }

    func sectionFor(index: Int) -> JournalSection {
        JournalSection(rawValue: index) ?? .timeline
    }
    
    func update(date: Date) {
            selectedDate = date
        }
}

enum JournalSection: Int, CaseIterable {
    case timeline
    case execution
    case analytics
    case notes

    var title: String {
        switch self {
        case .timeline:  return "Timeline"
        case .execution: return "Execution"
        case .analytics: return "Analytics"
        case .notes:     return "Notes"
        }
    }
}

extension Date {
    func toAPIDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: self)
    }
}
