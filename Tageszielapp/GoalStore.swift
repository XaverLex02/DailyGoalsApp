//
//  GoalStore.swift
//  DailyGoalsApp
//
//  Created by Xaver Lex on 15.05.25.
//

import Foundation
import SwiftUICore

class GoalStore: ObservableObject {
    @Published var goals: [Goal] = []

    func goals(for date: Date) -> [Goal] {
        goals.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func toggleAchieved(goal: Goal) {
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index].achieved.toggle()
        }
    }

    func addGoal(date: Date, category: GoalCategory) {
        goals.append(Goal(date: date, category: category, achieved: false))
    }
    
    func generateGoalsForMonth(date: Date) {
        let newGoals = GoalGenerator.generateGoals(for: date)
        for goal in newGoals {
            goals.append(goal)
        }
    }
}
