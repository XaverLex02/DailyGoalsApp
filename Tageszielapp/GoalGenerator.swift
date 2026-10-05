//
//  GoalGenerator.swift
//  DailyGoalsApp
//
//  Created by Xaver Lex on 16.05.25.
//

import Foundation

struct GoalGenerator {
    static func generateGoals(for baseDate: Date) -> [Goal] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: baseDate) else { return [] }

        var goals: [Goal] = []
        var date = monthInterval.start

        while date < monthInterval.end {
            for category in GoalCategory.allCases {
                goals.append(Goal(date: date, category: category, achieved: false))
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = nextDate
        }

        return goals
    }
}
