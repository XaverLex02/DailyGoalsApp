//
//  StatisticsView.swift
//  DailyGoalsApp
//
//  Created by Xaver Lex on 15.05.25.
//

import SwiftUICore
import SwiftUI
struct StatisticsView: View {
    @ObservedObject var store: GoalStore

    var body: some View {
        VStack(alignment: .leading) {
            Text("Zielstatistik").font(.title2)
            ForEach(GoalCategory.allCases) { category in
                let total = store.goals.filter { $0.category == category }.count
                let achieved = store.goals.filter { $0.category == category && $0.achieved }.count
                ProgressView("\(category.rawValue.capitalized): \(achieved)/\(total)",
                             value: Double(achieved), total: Double(max(total, 1)))
                    .accentColor(category.color)
            }
        }
        .padding()
    }
}
