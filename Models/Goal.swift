import SwiftUI

struct Goal: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var colorHex: String
    var symbol: String
    var description: String?

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    static let defaults: [Goal] = [
        Goal(id: UUID(uuidString: "A1B2C3D4-0001-0000-0000-000000000000")!, name: "Lesen",       colorHex: "#3B82F6", symbol: "book.fill"),
        Goal(id: UUID(uuidString: "A1B2C3D4-0002-0000-0000-000000000000")!, name: "Sport",       colorHex: "#F97316", symbol: "dumbbell.fill"),
        Goal(id: UUID(uuidString: "A1B2C3D4-0003-0000-0000-000000000000")!, name: "No YouTube",  colorHex: "#A855F7", symbol: "play.rectangle.fill"),
        Goal(id: UUID(uuidString: "A1B2C3D4-0004-0000-0000-000000000000")!, name: "Aufstehen",   colorHex: "#EAB308", symbol: "sunrise.fill"),
        Goal(id: UUID(uuidString: "A1B2C3D4-0005-0000-0000-000000000000")!, name: "Lernen",      colorHex: "#22C55E", symbol: "graduationcap.fill"),
    ]

    // Mapping von alten GoalType-rawValues zu Migration-UUIDs
    static let migrationMap: [String: UUID] = [
        "lesen":     UUID(uuidString: "A1B2C3D4-0001-0000-0000-000000000000")!,
        "sport":     UUID(uuidString: "A1B2C3D4-0002-0000-0000-000000000000")!,
        "noyt":      UUID(uuidString: "A1B2C3D4-0003-0000-0000-000000000000")!,
        "aufstehen": UUID(uuidString: "A1B2C3D4-0004-0000-0000-000000000000")!,
        "lernen":    UUID(uuidString: "A1B2C3D4-0005-0000-0000-000000000000")!,
    ]
}

private extension Color {
    init?(hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
