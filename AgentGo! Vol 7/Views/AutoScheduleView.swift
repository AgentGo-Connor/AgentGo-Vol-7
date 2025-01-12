import SwiftUI
import MapKit
import CoreLocation

struct AutoScheduleView: View {
    let date: Date
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var startTime: Date
    @State private var startingProperty: Property?
    @State private var selectedProperties: Set<Property> = []
    @State private var isProcessing = false
    @State private var existingOpenHomes: [ScheduledOpenHome] = []
    
    init(date: Date) {
        self.date = date
        _startTime = State(initialValue: date)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if !existingOpenHomes.isEmpty {
                    Section {
                        ForEach(existingOpenHomes) { openHome in
                            VStack(alignment: .leading) {
                                Text(openHome.property.streetAddress)
                                    .font(.headline)
                                Text("Manual Schedule: \(openHome.startTime, format: .dateTime.hour().minute())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Existing Open Homes")
                    } footer: {
                        Text("Auto schedule will work around these times")
                    }
                }
                
                Section {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                        .onChange(of: startTime) { _, newValue in
                            startTime = viewModel.roundToQuarterHour(newValue)
                        }
                } header: {
                    Text("Time")
                }
                
                Section {
                    Picker("Start From", selection: $startingProperty) {
                        Text("Select a property").tag(Optional<Property>.none)
                        ForEach(viewModel.properties) { property in
                            Text(property.streetAddress)
                                .tag(Optional(property))
                        }
                    }
                } header: {
                    Text("Starting Location")
                }
                
                Section {
                    if viewModel.properties.isEmpty {
                        Text("No properties added yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.properties) { property in
                            PropertyToggleRow(
                                property: property,
                                isSelected: selectedProperties.contains(property),
                                isDisabled: property == startingProperty
                            ) { isSelected in
                                if isSelected {
                                    selectedProperties.insert(property)
                                } else {
                                    selectedProperties.remove(property)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Properties")
                }
            }
            .background(colorScheme == .dark ? Color(.systemBackground) : Color(hex: "f2efeb"))
            .toolbarBackground(colorScheme == .dark ? Color(.systemBackground) : Color(hex: "f2efeb"), for: .navigationBar)
            .navigationTitle("Auto Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schedule") {
                        scheduleOpenHomes()
                    }
                    .disabled(!canSchedule)
                }
            }
            .overlay {
                if isProcessing {
                    ProgressView("Creating Schedule...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .onAppear {
                startTime = viewModel.getDefaultStartTime(for: date)
                loadExistingOpenHomes()
            }
        }
    }
    
    private var canSchedule: Bool {
        !selectedProperties.isEmpty && startingProperty != nil
    }
    
    private func loadExistingOpenHomes() {
        let startOfDay = Calendar.current.startOfDay(for: date)
        if let schedule = viewModel.schedules[startOfDay] {
            // Only keep manually scheduled open homes
            existingOpenHomes = schedule.openHomes.filter { _ in !schedule.isAutoScheduled }
        } else {
            existingOpenHomes = []
        }
    }
    
    private func scheduleOpenHomes() {
        guard let startingProperty = startingProperty else { return }
        
        isProcessing = true
        
        Task {
            // Get all properties to schedule
            var propertiesToSchedule = Array(selectedProperties)
            if let index = propertiesToSchedule.firstIndex(where: { $0.id == startingProperty.id }) {
                propertiesToSchedule.remove(at: index)
            }
            
            // Calculate optimal route considering existing homes
            let route = await calculateOptimalRoute(
                start: startingProperty,
                properties: propertiesToSchedule,
                existingHomes: existingOpenHomes
            )
            
            var scheduledHomes = existingOpenHomes // Start with existing manual schedules
            var currentTime = startTime
            
            // Function to check if we can schedule at a given time
            func canScheduleAt(_ proposedTime: Date, for property: Property) async -> Bool {
                let proposedHome = await createScheduledOpenHome(for: property, at: proposedTime)
                
                // Check for direct time conflicts
                if let _ = await findTimeConflict(for: proposedHome, with: scheduledHomes) {
                    return false
                }
                
                // Check if there's enough travel time to the next manual schedule
                if let nextManual = await existingOpenHomes.first(where: { $0.startTime > proposedHome.bufferAfterEnd }) {
                    let travelTime = await calculateTravelTime(
                        from: property.coordinates,
                        to: nextManual.property.coordinates
                    )
                    
                    // Add 30-minute safety buffer for travel to manual schedules
                    let requiredGap = travelTime + (30 * 60)
                    let actualGap = nextManual.bufferBeforeStart.timeIntervalSince(proposedHome.bufferAfterEnd)
                    
                    return actualGap >= requiredGap
                }
                
                return true
            }
            
            // Add starting property if it's not already scheduled
            if !existingOpenHomes.contains(where: { $0.property.id == startingProperty.id }) {
                var validStartTime = currentTime
                
                while !(await canScheduleAt(validStartTime, for: startingProperty)) {
                    validStartTime = validStartTime.addingTimeInterval(15 * 60) // Try 15 minutes later
                }
                
                let firstHome = createScheduledOpenHome(
                    for: startingProperty,
                    at: validStartTime
                )
                scheduledHomes.append(firstHome)
                currentTime = firstHome.bufferAfterEnd
            }
            
            // Add remaining properties
            for property in route {
                // Skip if already manually scheduled
                if existingOpenHomes.contains(where: { $0.property.id == property.id }) {
                    continue
                }
                
                if let lastHome = scheduledHomes.last {
                    let travelTime = await calculateTravelTime(
                        from: lastHome.property.coordinates,
                        to: property.coordinates
                    )
                    
                    // Add travel time plus safety buffer
                    currentTime = currentTime.addingTimeInterval(travelTime + (15 * 60))
                    currentTime = viewModel.roundToQuarterHour(currentTime)
                }
                
                // Find a valid time slot
                var validTime = currentTime
                while !(await canScheduleAt(validTime, for: property)) {
                    validTime = validTime.addingTimeInterval(15 * 60)
                }
                
                let newHome = createScheduledOpenHome(
                    for: property,
                    at: validTime
                )
                scheduledHomes.append(newHome)
                currentTime = newHome.bufferAfterEnd
            }
            
            // Sort homes by time
            scheduledHomes.sort { $0.startTime < $1.startTime }
            
            // Create the schedule
            let schedule = Schedule(
                date: date,
                openHomes: scheduledHomes,
                isAutoScheduled: false // Mark as mixed schedule
            )
            
            await MainActor.run {
                viewModel.setSchedule(schedule)
                isProcessing = false
                dismiss()
            }
        }
    }
    
    private func findTimeConflict(for newHome: ScheduledOpenHome, with existingHomes: [ScheduledOpenHome]) -> ScheduledOpenHome? {
        for existing in existingHomes {
            if newHome.bufferBeforeStart < existing.bufferAfterEnd &&
                newHome.bufferAfterEnd > existing.bufferBeforeStart {
                return existing
            }
        }
        return nil
    }
    
    private func findNextAvailableTime(after date: Date) -> Date {
        viewModel.roundToQuarterHour(date.addingTimeInterval(300)) // Add 5 minutes buffer
    }
    
    private func calculateOptimalRoute(start: Property, properties: [Property], existingHomes: [ScheduledOpenHome]) async -> [Property] {
        // Simple nearest neighbor algorithm
        var unvisited = properties
        var route: [Property] = []
        var current = start
        
        while !unvisited.isEmpty {
            var shortestDistance = Double.infinity
            var nextProperty: Property?
            var nextIndex: Int?
            
            // Find the nearest unvisited property
            for (index, property) in unvisited.enumerated() {
                let distance = calculateDistance(
                    from: current.coordinates,
                    to: property.coordinates
                )
                if distance < shortestDistance {
                    shortestDistance = distance
                    nextProperty = property
                    nextIndex = index
                }
            }
            
            if let property = nextProperty, let index = nextIndex {
                route.append(property)
                unvisited.remove(at: index)
                current = property
            }
        }
        
        return route
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let from = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let to = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return from.distance(from: to)
    }
    
    private func calculateTravelTime(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> TimeInterval {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        
        do {
            let response = try await MKDirections(request: request).calculate()
            return response.routes.first?.expectedTravelTime ?? 600 // Default to 10 minutes if calculation fails
        } catch {
            return 600 // Default to 10 minutes if calculation fails
        }
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

struct PropertyToggleRow: View {
    let property: Property
    let isSelected: Bool
    let isDisabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(property.streetAddress)
                Text(property.suburb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { onToggle($0) }
            ))
            .disabled(isDisabled)
        }
        .opacity(isDisabled ? 0.5 : 1)
    }
}

#Preview {
    AutoScheduleView(date: Date())
        .environmentObject(AppViewModel())
} 
