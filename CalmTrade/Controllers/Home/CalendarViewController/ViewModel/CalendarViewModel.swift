//
//  CalendarViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 12/11/25.
//

import Foundation

final class CalendarViewModel {

    private let api = APIService()

    var onLoading: ((Bool) -> Void)?
    var onData: ((MonthOverviewData) -> Void)?
    var onError: ((String) -> Void)?

    private let calendar = Calendar.current

    private var calendarWeeks: [CalendarWeek] = []

    // MARK: - API
    func load(month: Int, year: Int) {
        onLoading?(true)

        let path = "analytics/monthly-overview"
        let params: [String: Any] = ["month": month, "year": year]

        api.startService(with: .GET,
                         path: path,
                         parameters: params,
                         files: nil,
                         modelType: MonthOverviewResponse.self)
        { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                self.onLoading?(false)

                switch result {
                case .Success(let response):
                    guard let data = response?.data else {
                        self.onError?("Empty response")
                        return
                    }

                    self.calendarWeeks = self.buildTradingCalendar(from: data)
                    self.onData?(data)

                case .Error(let message):
                    self.onError?(message)
                }
            }
        }
    }

    // MARK: - Public for Controller

    func numberOfWeeks() -> Int {
        return calendarWeeks.count
    }

    func week(at index: Int) -> CalendarWeek {
        return calendarWeeks[index]
    }

    func weekItems(for week: CalendarWeek) -> [DayOrTotal] {
        return week.items
    }

    // MARK: - Build Trading Calendar Grid (Mon–Fri + Total)
    private func buildTradingCalendar(from data: MonthOverviewData) -> [CalendarWeek] {

        // Flatten all days from backend
        let tradingDays = data.weeks
            .flatMap { $0.days }
            .sorted { $0.date < $1.date }

        guard let firstValidDate = tradingDays.first?.date,
              let first = parseDate(firstValidDate) else {
            return []
        }

        // Create 6-column rows (Mon–Fri + Total)
        var result: [CalendarWeek] = []
        var currentRow = Array(repeating: DayOrTotal.day(Day.empty), count: 6)

        for week in data.weeks {
            // Reset row
            currentRow = Array(repeating: .day(Day.empty), count: 6)

            // Insert days into their weekday slots
            for day in week.days {
                guard let d = parseDate(day.date) else { continue }
                let weekday = calendar.component(.weekday, from: d)

                // Ignore Sat/Sun (backend never sends them)
                guard weekday >= 2 && weekday <= 6 else { continue }

                let colIndex = weekday - 2   // Mon=2 → 0, Tue=3 → 1, ... Fri=6 → 4

                if colIndex >= 0 && colIndex <= 4 {
                    currentRow[colIndex] = .day(day)
                }
            }

            // Insert weekly total column
            currentRow[5] = .total(week.weekTotal)

            result.append(CalendarWeek(items: currentRow))
        }

        return result
    }

    // MARK: - Utility

    private func parseDate(_ string: String) -> Date? {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = .current
        return df.date(from: string)
    }
}

// MARK: - Internal Model for UI
struct CalendarWeek {
    let items: [DayOrTotal] // count = 6 (Mon–Fri + Total)
}

// MARK: - Empty Placeholder Trading Day
extension Day {
    static var empty: Day {
        Day(date: "", pnl: 0, calmScore: nil, trades: 0)
    }
}

enum DayOrTotal {
    case day(Day)
    case total(WeekTotal)
}
