import SwiftUI
import MapKit
import CoreLocation

struct PlannerView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var selectedDate = Date()
    @State private var showingAutoSchedule = false
    @State private var showingManualSchedule = false
    @State private var showingResetOptions = false
    
    private var schedule: Schedule? {
        viewModel.schedules[Calendar.current.startOfDay(for: selectedDate)]
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Calendar View
                WeekCalendarView(selectedDate: $selectedDate)
                    .padding()
                
                // Schedule Content
                if let schedule = schedule {
                    ScheduleListView(schedule: schedule)
                } else {
                    EmptyScheduleView()
                }
                
                // Always show Auto Schedule Button
                Button {
                    showingAutoSchedule = true
                } label: {
                    Text("Auto Schedule")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.customAccent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("Planner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if schedule != nil {
                            Button {
                                showingResetOptions = true
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundStyle(Color.customAccent)
                            }
                        }
                        
                        Button {
                            showingManualSchedule = true
                        } label: {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundStyle(Color.customAccent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAutoSchedule) {
                AutoScheduleView(date: selectedDate)
            }
            .sheet(isPresented: $showingManualSchedule) {
                ManualScheduleView(date: selectedDate)
            }
            .confirmationDialog(
                "Reset Schedule",
                isPresented: $showingResetOptions,
                actions: {
                    Button("Reset This Day", role: .destructive) {
                        viewModel.resetSchedule(for: selectedDate)
                    }
                    Button("Reset All Days", role: .destructive) {
                        viewModel.resetAllSchedules()
                    }
                    Button("Cancel", role: .cancel) { }
                },
                message: {
                    Text("Choose how you would like to reset the schedule")
                }
            )
        }
    }
}

struct EmptyScheduleView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Open Homes Scheduled")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    PlannerView()
        .environmentObject(AppViewModel())
} 
