//
//  DateGenerator.swift
//  DailyGoalsApp
//
//  Created by Xaver Lex on 15.05.25.
//

import Foundation

struct DateGenerator {
    static func generateMonthDates(for baseDate: Date) -> [Date] {
        var dates: [Date] = []

        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: baseDate),
              let firstWeekStart = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)?.start,
              let lastWeekEnd = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end)?.end
        else { return [] }

        var current = firstWeekStart
        while current < lastWeekEnd {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        return dates
    }
}

