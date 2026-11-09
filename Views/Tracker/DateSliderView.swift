import SwiftUI

struct DateSliderView: View {
    @Binding var selectedDate: Date

    private var dates: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<31).compactMap {
            Calendar.current.date(byAdding: .day, value: -30 + $0, to: today)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dates, id: \.self) { date in
                        DateCardView(date: date, isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate))
                            .id(date)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedDate = date
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onAppear {
                let today = Calendar.current.startOfDay(for: Date())
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation {
                        proxy.scrollTo(today, anchor: .center)
                    }
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
