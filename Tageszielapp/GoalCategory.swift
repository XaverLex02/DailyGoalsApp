//
//  GoalCategory.swift
//  DailyGoalsApp
//
//  Created by Xaver Lex on 15.05.25.
//

import SwiftUICore

enum GoalCategory: String, CaseIterable, Identifiable {
    case Sport, Lesen, Bildung, NoYT, Aufstehen
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .Sport: return .blue
        case .Lesen: return .green
        case .Bildung: return .orange
        case .Aufstehen: return .gray
        case .NoYT: return .pink
        }
    }
}
