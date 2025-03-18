//
//  Calendar.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 2/7/25.
//
import SwiftUI

struct CalendarView: View {
    @Binding var isSpanish: Bool  // Binding to control language selection
    @State private var selectedDate = Date()
    @State private var currentMonthDate = Date()
    
    private var daysOfWeek: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isSpanish ? "es_ES" : "en_US")
        return formatter.veryShortWeekdaySymbols
    }
    
    
    private var currentMonth: [Date] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: currentMonthDate)!
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonthDate))!
        
        var days: [Date] = []
        
        // Add leading empty days before the first day of the month
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1
        for _ in 0..<firstWeekday {
            days.append(Date.distantPast)  // Dummy date for empty space
        }
        
        // Add the actual days of the month
        for day in range {
            if let dayDate = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(dayDate)
            }
        }
        
        return days
    }
    
    private func isSelected(date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date, inSameDayAs: selectedDate)
    }
    
    private func monthYearString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isSpanish ? "es_ES" : "en_US")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date).capitalized
    }
    
    private func goToNextMonth() {
        currentMonthDate = Calendar.current.date(byAdding: .month, value: 1, to: currentMonthDate) ?? currentMonthDate
    }
    
    private func goToPreviousMonth() {
        currentMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: currentMonthDate) ?? currentMonthDate
    }
    
    var body: some View {
        VStack {
            ZStack {
                Color.white
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .frame(maxWidth: 500, maxHeight: 600) // Limit the size
                
                VStack(spacing: 0) {
                    // Month Header Section
                    HStack {
                        Button(action: goToPreviousMonth) {
                            Image(systemName: "chevron.left")
                                .font(.title)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        Text(monthYearString(date: currentMonthDate))
                            .font(.title)
                            .bold()
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        Button(action: goToNextMonth) {
                            Image(systemName: "chevron.right")
                                .font(.title)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding([.horizontal, .top])
                    
                    Divider()
                    
                    // Weekday Row Section
                    HStack {
                        ForEach(daysOfWeek, id: \.self) { day in
                            Text(day.prefix(1))
                                .font(.headline)
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity) // Ensure equal spacing
                        }
                    }
                    .padding(.vertical, 5)
                    
                    Divider()
                    
                    // Calendar Days Grid Section
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                        ForEach(currentMonth, id: \.self) { date in
                            if date == Date.distantPast {
                                Rectangle()
                                    .foregroundColor(.clear)
                                    .frame(height: 30)
                            } else {
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .frame(width: 30, height: 30)
                                    .background(isSelected(date: date) ? Color.orange : Color.clear)
                                    .cornerRadius(15)
                                    .onTapGesture {
                                        selectedDate = date
                                    }
                                    .foregroundColor(isSelected(date: date) ? Color.white : Color.black)
                            }
                        }
                    }
                    .padding()
                    Spacer()
                }
                .padding()
            }
            .frame(maxWidth: 500, maxHeight: 600) // Enforce consistent calendar size
            .padding()
        }
        .background(Color(.gray))
    }
}
