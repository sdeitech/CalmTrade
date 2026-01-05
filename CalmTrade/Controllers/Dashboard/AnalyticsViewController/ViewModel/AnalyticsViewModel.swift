//
//  AnalyticsViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 21/11/25.
//


import UIKit
import Combine

final class AnalyticsViewModel {

    @Published var selectedSection: AnalyticsSection = .topAnalytics

    // Create view controllers for 3 sections
    func viewControllers() -> [UIViewController] {
        let sb = UIStoryboard(name: Constants.Storyboard.Analytics, bundle: nil)

        let top = sb.instantiateViewController(withIdentifier: "AnalyticsDashboardViewController")
        let trades = sb.instantiateViewController(withIdentifier: "TradesViewController")
        let stats = sb.instantiateViewController(withIdentifier: "OverallStatsViewController")

        return [top, trades, stats]
    }


    func indexFor(section: AnalyticsSection) -> Int {
        return section.rawValue
    }

    func sectionFor(index: Int) -> AnalyticsSection {
        return AnalyticsSection(rawValue: index) ?? .overallStats
    }
}

enum AnalyticsSection: Int, CaseIterable {
    case topAnalytics
    case trades
    case overallStats

    var title: String {
        switch self {
        case .topAnalytics: return "Top Analytics"
        case .trades: return "Trades"
        case .overallStats: return "Overall Stats"
        }
    }
}
