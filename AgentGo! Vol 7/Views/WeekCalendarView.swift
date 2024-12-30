import SwiftUI

struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var monthOffset = 0
    @State private var weeks: [Date] = []
    @State private var currentPage = 0
    @State private var showingDatePicker = false
    
    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        return calendar
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Month header with date picker button
            Button {
                showingDatePicker = true
            } label: {
                HStack {
                    Text(getMonthTitle(for: currentPage))
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.customAccent)
                    
                    Spacer()
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationStack {
                    DatePickerView(selectedDate: $selectedDate, showPicker: $showingDatePicker)
                        .onChange(of: selectedDate) { _, newDate in
                            withAnimation {
                                currentPage = calculatePageForDate(newDate)
                            }
                        }
                }
                .presentationDetents([.height(420)])
            }
            
            // Week view
            TabView(selection: $currentPage) {
                ForEach(-50...50, id: \.self) { index in
                    WeekView(
                        weekStart: getWeekStart(for: index),
                        selectedDate: $selectedDate,
                        hasSchedule: hasSchedule
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 80)
        }
        .onAppear {
            // Set initial page based on selected date
            currentPage = calculatePageForDate(selectedDate)
        }
    }
    
    private func calculatePageForDate(_ date: Date) -> Int {
        let today = Date()
        let todayComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        let dateComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        
        guard let todayWeek = calendar.date(from: todayComponents),
              let dateWeek = calendar.date(from: dateComponents) else {
            return 0
        }
        
        let weekDifference = calendar.dateComponents([.weekOfYear], from: todayWeek, to: dateWeek)
        return weekDifference.weekOfYear ?? 0
    }
    
    private func getMonthTitle(for page: Int) -> String {
        let date = calendar.date(byAdding: .weekOfYear, value: page, to: Date()) ?? Date()
        return date.formatted(.dateTime.month(.wide))
    }
    
    private func getWeekStart(for weekOffset: Int) -> Date {
        let today = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        return calendar.date(byAdding: .weekOfYear, value: weekOffset, to: weekStart) ?? today
    }
    
    private func hasSchedule(on date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        return viewModel.schedules[startOfDay] != nil
    }
}

struct WeekView: View {
    let weekStart: Date
    @Binding var selectedDate: Date
    let hasSchedule: (Date) -> Bool
    
    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        return calendar
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<7) { dayOffset in
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                    DayButton(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        hasSchedule: hasSchedule(date)
                    ) {
                        withAnimation {
                            selectedDate = date
                        }
                    }
                }
            }
        }
    }
}

struct DayButton: View {
    let date: Date
    let isSelected: Bool
    let hasSchedule: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(date, format: .dateTime.weekday(.short))
                    .font(.caption)
                Text(date, format: .dateTime.day())
                    .font(.title3.bold())
                
                // Schedule indicator
                if hasSchedule {
                    Circle()
                        .fill(Color.customAccent)
                        .frame(width: 4, height: 4)
                } else {
                    Circle()
                        .fill(.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 44, height: 64)
            .background(isSelected ? Color.customAccent.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.customAccent, lineWidth: 2)
                }
            }
        }
        .foregroundStyle(isSelected ? .primary : .secondary)
    }
}

struct DatePickerView: View {
    @Binding var selectedDate: Date
    @Binding var showPicker: Bool
    
    var body: some View {
        VStack {
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .padding()
            
            Button("Done") {
                showPicker = false
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.customAccent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()
        }
    }
}

#Preview {
    WeekCalendarView(selectedDate: .constant(Date()))
        .environmentObject(AppViewModel())
} 