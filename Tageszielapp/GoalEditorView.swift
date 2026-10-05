//
//  GoalEditorView.swift
//  DailyGoalsApp
//
//  Created by Xaver Lex on 16.05.25.
//

import SwiftUICore
import SwiftUI

struct GoalEditorView: View {
    let date: Date
    var goals: [Goal]
    var toggleAchieved: (Goal) -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(goals) { goal in
                    HStack {
                        Text(goal.category.rawValue)
                        Spacer()
                        Button(action: {
                            toggleAchieved(goal)
                        }) {
                            Image(systemName: goal.achieved ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(goal.category.color)
                        }
                    }
                }
            }
            .navigationTitle("Goals on \(formattedDate(date))")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
