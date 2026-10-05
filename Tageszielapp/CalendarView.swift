//
//  CalendarView.swift
//  DailyGoalsApp
//
//  Created by Xaver Lex on 15.05.25.
//

import SwiftUICore
import SwiftUI

struct CalendarView: View {
    @ObservedObject var store: GoalStore
    @State private var displayedMonth: Date = Date()
    var monthDates: [Date] {
        DateGenerator.generateMonthDates(for: displayedMonth)
    }
    @State private var selectedDate: Date? = nil
    @State private var showGoalEditor = false

    var body: some View {
        VStack {
            Text("Tagesziele Kalender").font(.title)
            HStack {
                Button(action: {
                    displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                }) {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(monthYearString(from: displayedMonth))
                    .font(.headline)

                Spacer()

                Button(action: {
                    displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    store.generateGoalsForMonth(date: displayedMonth)
                }) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)

            let columns = Array(repeating: GridItem(.flexible()), count: 7)
            LazyVGrid(columns: columns) {
                ForEach(monthDates, id: \.self) { date in
                    let day = Calendar.current.component(.day, from: date)
                    let achievedGoals = store.goals(for: date).filter { $0.achieved}
                    let notAchievedGoals = store.goals(for: date).filter { !$0.achieved}
                    VStack {
                        Text("\(day)")
                            .font(.caption)
                        ForEach(achievedGoals) { goal in
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(goal.category.color)
                                .font(.caption2)
                        }
                        ForEach(notAchievedGoals) { goal in
                            Image(systemName: "circle")
                                .foregroundColor(goal.category.color)
                                .font(.caption2)
                        }
                    }
                    .padding(4)
                    .sheet(isPresented: $showGoalEditor) {
                        if let selectedDate = selectedDate {
                            GoalEditorView(
                                date: selectedDate,
                                goals: store.goals(for: selectedDate),
                                toggleAchieved: { goal in
                                    store.toggleAchieved(goal: goal)
                                }
                            )
                        }
                    }
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(6)
                    .onTapGesture {
                        selectedDate = date
                        showGoalEditor = !showGoalEditor
                    }
                }
            }
        }
        .padding()
    }
    func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

}

