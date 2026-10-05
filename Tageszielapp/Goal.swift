//
//  Goal.swift
//  DailyGoalsApp
//
//  Created by Xaver Lex on 15.05.25.
//

import Foundation

struct Goal: Identifiable {
    let id = UUID()
    let date: Date
    let category: GoalCategory
    var achieved: Bool
}
