import SwiftUI
import MapKit
import CoreLocation

struct ScheduleListView: View {
    let schedule: Schedule
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showingMapView = false
    @State private var showingDeleteAlert = false
    @State private var openHomeToDelete: ScheduledOpenHome?
    @State private var selectedOpenHome: ScheduledOpenHome?
    @State private var showingActionSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(schedule.openHomes.enumerated()), id: \.element.id) { index, openHome in
                    VStack(spacing: 8) {
                        if index > 0 {
                            TravelTimeView(
                                from: schedule.openHomes[index - 1],
                                to: openHome
                            )
                        }
                        
                        OpenHomeCard(openHome: openHome)
                            .onTapGesture {
                                selectedOpenHome = openHome
                                showingActionSheet = true
                            }
                    }
                }
            }
            .padding()
            
            if !schedule.openHomes.isEmpty {
                Button {
                    showingMapView = true
                } label: {
                    Label("View in Map", systemImage: "map")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                        .foregroundStyle(Color.customAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
        }
        .confirmationDialog(
            "Open Home Options",
            isPresented: $showingActionSheet,
            presenting: selectedOpenHome
        ) { openHome in
            Button("SMS Vendor") {
                sendSMS(to: openHome.property.clientPhone)
            }
            .disabled(openHome.property.clientPhone.isEmpty)
            
            Button("WhatsApp Message") {
                sendWhatsApp(to: openHome.property.clientPhone)
            }
            .disabled(openHome.property.clientPhone.isEmpty)
            
            Button("Delete Open Home", role: .destructive) {
                openHomeToDelete = openHome
                showingDeleteAlert = true
            }
            
            Button("Cancel", role: .cancel) { }
        } message: { openHome in
            Text(openHome.property.streetAddress)
        }
        .alert("Delete Open Home", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                openHomeToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let openHome = openHomeToDelete {
                    deleteAndReschedule(openHome)
                }
                openHomeToDelete = nil
            }
        } message: {
            if let openHome = openHomeToDelete {
                Text("Are you sure you want to delete the open home at \(openHome.property.streetAddress)?")
            }
        }
        .sheet(isPresented: $showingMapView) {
            NavigationStack {
                RouteMapView(schedule: schedule)
                    .navigationTitle("Route Map")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingMapView = false
                            }
                            .foregroundStyle(Color.customAccent)
                        }
                    }
            }
        }
    }
    
    private func sendSMS(to phoneNumber: String) {
        let smsURL = URL(string: "sms:\(phoneNumber)")!
        UIApplication.shared.open(smsURL)
    }
    
    private func sendWhatsApp(to phoneNumber: String) {
        // Remove any non-numeric characters from the phone number
        let cleanNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Create WhatsApp URL with the phone number
        // Note: WhatsApp requires the number to be in international format (e.g., +61)
        let whatsappURL = URL(string: "whatsapp://send?phone=\(cleanNumber)")!
        
        if UIApplication.shared.canOpenURL(whatsappURL) {
            UIApplication.shared.open(whatsappURL)
        } else {
            // WhatsApp is not installed, open App Store
            if let appStoreURL = URL(string: "itms-apps://itunes.apple.com/app/id310633997") {
                UIApplication.shared.open(appStoreURL)
            }
        }
    }
    
    private func deleteAndReschedule(_ openHome: ScheduledOpenHome) {
        // Get the current schedule
        let startOfDay = Calendar.current.startOfDay(for: schedule.date)
        guard var currentSchedule = viewModel.schedules[startOfDay] else { return }
        
        // Find properties that need rescheduling (ones after the deleted one)
        let deletedIndex = currentSchedule.openHomes.firstIndex(of: openHome)!
        let remainingHomes = Array(currentSchedule.openHomes.suffix(from: deletedIndex + 1))
        
        // Get the property before the deleted one (if any)
        let previousHome = deletedIndex > 0 ? currentSchedule.openHomes[deletedIndex - 1] : nil
        
        // Remove the deleted home and all homes after it
        currentSchedule.openHomes.removeSubrange(deletedIndex...)
        viewModel.setSchedule(currentSchedule)
        
        // If there are homes to reschedule
        if !remainingHomes.isEmpty {
            Task {
                var scheduledHomes = currentSchedule.openHomes
                
                // Start from either the previous home's end time or the first remaining home's original time
                let initialTime = previousHome?.bufferAfterEnd ?? remainingHomes.first?.startTime ?? schedule.date
                var currentTime = initialTime
                
                for property in remainingHomes.map(\.property) {
                    // Calculate travel time from previous property
                    if let lastHome = scheduledHomes.last {
                        let travelTime = await calculateTravelTime(
                            from: lastHome.property.coordinates,
                            to: property.coordinates
                        )
                        
                        // Add travel time plus 15-minute safety buffer
                        let totalRequiredTime = travelTime + (15 * 60) // 15 minutes in seconds
                        currentTime = currentTime.addingTimeInterval(totalRequiredTime)
                        currentTime = viewModel.roundToQuarterHour(currentTime)
                        
                        // Create new scheduled home
                        let newHome = createScheduledOpenHome(
                            for: property,
                            at: currentTime
                        )
                        
                        // Double check there's enough travel time
                        let actualTravelTime = newHome.bufferBeforeStart.timeIntervalSince(lastHome.bufferAfterEnd)
                        if actualTravelTime < totalRequiredTime {
                            // Not enough time, push this home later
                            let additionalTime = totalRequiredTime - actualTravelTime
                            currentTime = currentTime.addingTimeInterval(additionalTime)
                            currentTime = viewModel.roundToQuarterHour(currentTime)
                            
                            // Create adjusted home with new time
                            let adjustedHome = createScheduledOpenHome(
                                for: property,
                                at: currentTime
                            )
                            scheduledHomes.append(adjustedHome)
                            currentTime = adjustedHome.bufferAfterEnd
                        } else {
                            // Enough time, use original schedule
                            scheduledHomes.append(newHome)
                            currentTime = newHome.bufferAfterEnd
                        }
                    } else {
                        // First home after deletion
                        if let previousHome = previousHome {
                            // Calculate travel time from the home before deletion
                            let travelTime = await calculateTravelTime(
                                from: previousHome.property.coordinates,
                                to: property.coordinates
                            )
                            
                            // Add travel time plus safety buffer
                            let totalRequiredTime = travelTime + (15 * 60)
                            currentTime = currentTime.addingTimeInterval(totalRequiredTime)
                        }
                        
                        currentTime = viewModel.roundToQuarterHour(currentTime)
                        let newHome = createScheduledOpenHome(
                            for: property,
                            at: currentTime
                        )
                        scheduledHomes.append(newHome)
                        currentTime = newHome.bufferAfterEnd
                    }
                }
                
                // Update schedule with rescheduled homes
                let updatedSchedule = Schedule(
                    date: schedule.date,
                    openHomes: scheduledHomes,
                    isAutoScheduled: true
                )
                
                await MainActor.run {
                    viewModel.setSchedule(updatedSchedule)
                }
            }
        }
    }
    
    private func calculateTravelTime(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> TimeInterval {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        
        do {
            let response = try await MKDirections(request: request).calculate()
            return response.routes.first?.expectedTravelTime ?? 600
        } catch {
            return 600
        }
    }
    
    private func createScheduledOpenHome(for property: Property, at selectedTime: Date) -> ScheduledOpenHome {
        let openHomeStart = viewModel.roundToQuarterHour(selectedTime)
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

struct OpenHomeCard: View {
    let openHome: ScheduledOpenHome
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(openHome.property.streetAddress)
                .font(.headline)
            
            Text(openHome.property.suburb)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                TimelineView(openHome: openHome)
                Spacer()
                ClientInfoView(property: openHome.property)
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color(uiColor: .systemGray6) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5)
    }
}

struct TimelineView: View {
    let openHome: ScheduledOpenHome
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TimeRow(time: openHome.bufferBeforeStart, label: "Buffer Start")
            TimeRow(time: openHome.startTime, label: "Open Home Start")
            TimeRow(time: openHome.endTime, label: "Open Home End")
            TimeRow(time: openHome.bufferAfterEnd, label: "Buffer End")
        }
        .font(.caption)
    }
}

struct TimeRow: View {
    let time: Date
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(time, format: .dateTime.hour().minute())
                .monospacedDigit()
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

struct ClientInfoView: View {
    let property: Property
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if !property.clientFirstName.isEmpty {
                Text("\(property.clientFirstName) \(property.clientLastName)")
                    .font(.caption)
            }
            if !property.clientPhone.isEmpty {
                Text(property.clientPhone)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ScheduleListView(schedule: Schedule(
        date: Date(),
        openHomes: []
    ))
    .environmentObject(AppViewModel())
} 