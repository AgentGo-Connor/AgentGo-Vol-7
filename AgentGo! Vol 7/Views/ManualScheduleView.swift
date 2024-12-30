import SwiftUI

struct ManualScheduleView: View {
    let date: Date
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel
    
    @State private var selectedProperty: Property?
    @State private var startTime: Date
    @State private var existingSchedules: [ScheduledOpenHome] = []
    @State private var showingTimeConflictAlert = false
    
    init(date: Date) {
        self.date = date
        _startTime = State(initialValue: AppViewModel().getDefaultStartTime(for: date))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                        .onChange(of: startTime) { _, newValue in
                            startTime = viewModel.roundToQuarterHour(newValue)
                        }
                } header: {
                    Text("Time")
                }
                
                Section("Property") {
                    if viewModel.properties.isEmpty {
                        Text("No properties added yet")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Select Property", selection: $selectedProperty) {
                            Text("Select a property").tag(Optional<Property>.none)
                            ForEach(viewModel.properties) { property in
                                PropertyPickerRow(property: property)
                                    .tag(Optional(property))
                            }
                        }
                    }
                }
                
                if let property = selectedProperty {
                    Section("Duration") {
                        VStack(alignment: .leading) {
                            Text("Open Home: \(property.openHomeDuration) minutes")
                            Text("Buffer Before: \(property.bufferBefore) minutes")
                            Text("Buffer After: \(property.bufferAfter) minutes")
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                
                if !existingSchedules.isEmpty {
                    Section("Other Open Homes This Day") {
                        ForEach(existingSchedules) { openHome in
                            ExistingOpenHomeRow(openHome: openHome)
                        }
                    }
                }
            }
            .navigationTitle("Manual Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addOpenHome()
                    }
                    .disabled(selectedProperty == nil)
                }
            }
            .alert("Time Conflict", isPresented: $showingTimeConflictAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The selected time conflicts with an existing open home. Please choose a different time.")
            }
            .onAppear {
                loadExistingSchedules()
            }
        }
    }
    
    private func loadExistingSchedules() {
        let startOfDay = Calendar.current.startOfDay(for: date)
        if let schedule = viewModel.schedules[startOfDay] {
            existingSchedules = schedule.openHomes
        } else {
            existingSchedules = []
        }
    }
    
    private func addOpenHome() {
        guard let property = selectedProperty else { return }
        
        let newOpenHome = createScheduledOpenHome(for: property, at: startTime)
        
        // Check for time conflicts
        if hasTimeConflict(newOpenHome) {
            showingTimeConflictAlert = true
            return
        }
        
        // Add to existing schedule or create new one
        let startOfDay = Calendar.current.startOfDay(for: date)
        if var existingSchedule = viewModel.schedules[startOfDay] {
            existingSchedule.openHomes.append(newOpenHome)
            existingSchedule.openHomes.sort { $0.startTime < $1.startTime }
            viewModel.setSchedule(existingSchedule)
        } else {
            let schedule = Schedule(
                date: date,
                openHomes: [newOpenHome],
                isAutoScheduled: false
            )
            viewModel.setSchedule(schedule)
        }
        
        dismiss()
    }
    
    private func hasTimeConflict(_ newOpenHome: ScheduledOpenHome) -> Bool {
        for existing in existingSchedules {
            if newOpenHome.bufferBeforeStart < existing.bufferAfterEnd &&
                newOpenHome.bufferAfterEnd > existing.bufferBeforeStart {
                return true
            }
        }
        return false
    }
    
    private func createScheduledOpenHome(for property: Property, at selectedTime: Date) -> ScheduledOpenHome {
        // First, round the selected time to get the open home start time
        let openHomeStart = viewModel.roundToQuarterHour(selectedTime)
        
        // Calculate buffer start by subtracting buffer time from rounded open home start
        let bufferBeforeStart = openHomeStart.addingTimeInterval(-TimeInterval(property.bufferBefore * 60))
        let openHomeEnd = openHomeStart.addingTimeInterval(TimeInterval(property.openHomeDuration * 60))
        let bufferAfterEnd = openHomeEnd.addingTimeInterval(TimeInterval(property.bufferAfter * 60))
        
        return ScheduledOpenHome(
            id: UUID(),
            property: property,
            startTime: openHomeStart,
            endTime: openHomeEnd,
            bufferBeforeStart: bufferBeforeStart,
            bufferAfterEnd: bufferAfterEnd
        )
    }
}

struct PropertyPickerRow: View {
    let property: Property
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(property.streetAddress)
            Text(property.suburb)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ExistingOpenHomeRow: View {
    let openHome: ScheduledOpenHome
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(openHome.property.streetAddress)
                .font(.subheadline)
            HStack {
                Text(openHome.startTime, format: .dateTime.hour().minute())
                Text("-")
                Text(openHome.endTime, format: .dateTime.hour().minute())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ManualScheduleView(date: Date())
        .environmentObject(AppViewModel())
} 