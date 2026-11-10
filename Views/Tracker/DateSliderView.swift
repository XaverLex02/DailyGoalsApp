import SwiftUI

struct DateSliderView: View {
    @Binding var selectedDate: Date
    var today: Date = Calendar.current.startOfDay(for: Date())

    private var dates: [Date] {
        (0..<31).compactMap {
            Calendar.current.date(byAdding: .day, value: -30 + $0, to: today)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dates, id: \.self) { date in
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        // Echter Button statt onTapGesture, damit VoiceOver die Karte als bedienbar erkennt
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDate = date
                            }
                        } label: {
                            DateCardView(date: date, isSelected: isSelected)
                        }
                        .buttonStyle(.plain)
                        .id(date)
                        .accessibilityLabel(DateCardView.accessibilityLabel(for: date, today: today))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation {
                        proxy.scrollTo(today, anchor: .center)
                    }
                }
            }
            .onChange(of: today) { _, newToday in
                withAnimation {
                    proxy.scrollTo(newToday, anchor: .center)
                }
            }
        }
    }
}

private struct DateCardView: View {
    let date: Date
    let isSelected: Bool

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        f.locale = Locale(identifier: "de_DE")
        return f
    }()

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d. MMMM"
        f.locale = Locale(identifier: "de_DE")
        return f
    }()

    /// z. B. „Heute, Montag, 9. November“
    static func accessibilityLabel(for date: Date, today: Date) -> String {
        let text = fullDateFormatter.string(from: date)
        return Calendar.current.isDate(date, inSameDayAs: today) ? "Heute, \(text)" : text
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    var body: some View {
        VStack(spacing: 4) {
            Text(Self.weekdayFormatter.string(from: date).uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : .secondary)

            Text(Self.dayFormatter.string(from: date))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .frame(width: 44, height: 60)
        .background(
            Capsule()
                .fill(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    DateSliderView(selectedDate: .constant(Date()))
        .background(Color(uiColor: .systemGroupedBackground))
}
