//
//  Calendar.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 2/7/25.
//


import SwiftUI

struct CalendarView: View {
    @State private var selectedDate = Date()
    @State private var currentMonthDate = Date()
    
    private var daysOfWeek: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return Calendar.current.weekdaySymbols
    }

    private var currentMonth: [Date] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: currentMonthDate)!
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonthDate))!
        
        var days: [Date] = []
        
        // Add leading empty days before the first day of the month
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1 // Adjust for Sunday as 1
        for _ in 0..<firstWeekday {
            days.append(Date.distantPast) // Dummy date for empty space
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
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func goToNextMonth() {
        currentMonthDate = Calendar.current.date(byAdding: .month, value: 1, to: currentMonthDate) ?? currentMonthDate
    }

    private func goToPreviousMonth() {
        currentMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: currentMonthDate) ?? currentMonthDate
    }

    var body: some View {
        VStack {
            // Background square for the entire calendar (header + days)
            ZStack {
                Color.white
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                VStack(spacing: 0) {
                    // Month Header Section (Month and Year)
                    HStack {
                        Button(action: {
                            goToPreviousMonth()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title)
                                .foregroundColor(.orange)
                        }
                        
                        Text(monthYearString(date: currentMonthDate))
                            .font(.largeTitle)
                            .bold()
                            .padding()
                            .foregroundColor(.orange)
                        
                        Button(action: {
                            goToNextMonth()
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.title)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.bottom, 5) // Padding between header and weekdays

                    // Weekday Row Section
                    HStack {
                        ForEach(daysOfWeek, id: \.self) { day in
                            Text(day.prefix(1))
                                .frame(maxWidth: 53.5)
                                .padding(.top, 8)
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                    }

                    // Calendar Days Grid Section
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 7), spacing: 10) {
                        ForEach(currentMonth, id: \.self) { date in
                            if date == Date.distantPast {
                                // Empty space
                                Rectangle()
                                    .foregroundColor(.clear)
                                    .frame(width: 30, height: 30)
                            } else {
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .frame(width: 30, height: 30)
                                    .background(self.isSelected(date: date) ? Color.orange : Color.clear)
                                    .cornerRadius(15)
                                    .onTapGesture {
                                        selectedDate = date
                                    }
                                    .foregroundColor(self.isSelected(date: date) ? Color.white : Color.black)
                            }
                        }
                    }
                    .padding()
                }
            }
            .padding() // Padding around the whole calendar square
        }
        .background(Color(.gray)) // Ensures dark mode support
       // .edgesIgnoringSafeArea(.all) // Extend to the edges
    }
}
