import SwiftUI
import MapKit
import CoreLocation

struct ScheduleListView: View {
    let schedule: Schedule
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var travelTimes: [String: TravelInfo] = [:]
    @State private var showingRouteMap = false
    
    private var totalInfo: (minutes: Int, kilometers: Double) {
        let totalKilometers = travelTimes.values.reduce(0.0) { $0 + $1.kilometers }
        
        // Calculate total schedule duration
        if let firstHome = schedule.openHomes.first, let lastHome = schedule.openHomes.last {
            let totalMinutes = Int(lastHome.bufferAfterEnd.timeIntervalSince(firstHome.bufferBeforeStart) / 60)
            return (totalMinutes, totalKilometers)
        }
        return (0, totalKilometers)
    }
    
    private var totalTimeFormatted: String {
        let hours = totalInfo.minutes / 60
        let minutes = totalInfo.minutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !schedule.openHomes.isEmpty {
                    HStack {
                        if schedule.openHomes.count > 1 {
                            Text("\(String(format: "%.1f", totalInfo.kilometers))km • \(totalTimeFormatted)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            showingRouteMap = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "map.fill")
                                    .imageScale(.small)
                                Text("View Route")
                                    .fontWeight(.medium)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.customAccent)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                
                ForEach(Array(schedule.openHomes.enumerated()), id: \.element.id) { index, openHome in
                    VStack(spacing: 8) {
                        // Show travel info if this isn't the first open home
                        if index > 0 {
                            let previousOpenHome = schedule.openHomes[index - 1]
                            let key = "\(previousOpenHome.id)-\(openHome.id)"
                            if let travelInfo = travelTimes[key] {
                                TravelInfoView(travelInfo: travelInfo)
                            }
                        }
                        
                        OpenHomeCard(openHome: openHome)
                            .frame(width: UIScreen.main.bounds.width * 0.9)
                    }
                }
            }
            .padding(.vertical)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showingRouteMap) {
            OpenHomeRouteMapView(openHomes: schedule.openHomes)
        }
        .task {
            await calculateTravelTimes()
        }
    }
    
    private func calculateTravelTimes() async {
        let openHomes = schedule.openHomes
        guard openHomes.count > 1 else { return }
        
        for i in 0..<(openHomes.count - 1) {
            let start = openHomes[i]
            let end = openHomes[i + 1]
            let key = "\(start.id)-\(end.id)"
            
            let startLocation = start.property.coordinates
            let endLocation = end.property.coordinates
            
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: startLocation))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: endLocation))
            request.transportType = .automobile
            
            do {
                let directions = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MKDirections.Response, Error>) in
                    MKDirections(request: request).calculate { response, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let response = response {
                            continuation.resume(returning: response)
                        } else {
                            continuation.resume(throwing: NSError(domain: "MapError", code: -1))
                        }
                    }
                }
                
                if let route = directions.routes.first {
                    let travelTime = Int(route.expectedTravelTime / 60) // Convert to minutes
                    let distance = route.distance / 1000 // Convert to kilometers
                    
                    await MainActor.run {
                        travelTimes[key] = TravelInfo(minutes: travelTime, kilometers: distance)
                    }
                }
            } catch {
                print("Error calculating travel time: \(error)")
            }
        }
    }
}

struct TravelInfo {
    let minutes: Int
    let kilometers: Double
}

struct TravelInfoView: View {
    let travelInfo: TravelInfo
    
    var body: some View {
        HStack {
            Image(systemName: "car.fill")
                .foregroundStyle(Color.customAccent)
            
            Text("\(travelInfo.minutes) min")
                .fontWeight(.medium)
            
            Text("•")
                .foregroundStyle(.secondary)
            
            Text(String(format: "%.1f km", travelInfo.kilometers))
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(Color.customAccent.opacity(0.1))
        .clipShape(Capsule())
    }
}

struct OpenHomeHeaderView: View {
    let openHome: ScheduledOpenHome
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(openHome.property.streetAddress)
                    .font(.headline)
                Text(openHome.property.suburb)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            
            Text("\(openHome.duration)min")
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.customAccent.opacity(0.1))
                .foregroundStyle(Color.customAccent)
                .clipShape(Capsule())
        }
    }
}

struct OpenHomeTimesView: View {
    let openHome: ScheduledOpenHome
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "clock")
                    Text(openHome.startTime, format: .dateTime.hour().minute())
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                    Text(openHome.endTime, format: .dateTime.hour().minute())
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Before: \(openHome.property.bufferBefore)min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("After: \(openHome.property.bufferAfter)min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct OpenHomeClientInfoView: View {
    let property: Property
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !property.clientFirstName.isEmpty {
                Label("\(property.clientFirstName) \(property.clientLastName)", systemImage: "person")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if !property.clientPhone.isEmpty {
                Label(property.clientPhone, systemImage: "phone")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct OpenHomeCard: View {
    let openHome: ScheduledOpenHome
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingActionSheet = false
    @State private var showingDeleteAlert = false
    
    private var formattedPhoneNumber: String {
        openHome.property.clientPhone.replacingOccurrences(of: " ", with: "")
    }
    
    private var whatsappURL: URL? {
        URL(string: "https://wa.me/\(formattedPhoneNumber)")
    }
    
    private var phoneURL: URL? {
        URL(string: "tel://\(formattedPhoneNumber)")
    }
    
    private var smsURL: URL? {
        URL(string: "sms://\(formattedPhoneNumber)")
    }
    
    var body: some View {
        VStack(spacing: 12) {
            OpenHomeHeaderView(openHome: openHome)
            
            Divider()
            
            OpenHomeTimesView(openHome: openHome)
            
            if !openHome.property.clientFirstName.isEmpty || !openHome.property.clientPhone.isEmpty {
                Divider()
                OpenHomeClientInfoView(property: openHome.property)
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? Color(.systemGray6) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.1),
                radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.1),
                       lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            showingActionSheet = true
        }
        .confirmationDialog("Open Home Options", isPresented: $showingActionSheet) {
            if !openHome.property.clientPhone.isEmpty {
                if let phoneURL = phoneURL {
                    Button("Call Client") {
                        UIApplication.shared.open(phoneURL)
                    }
                }
                
                if let smsURL = smsURL {
                    Button("Send SMS") {
                        UIApplication.shared.open(smsURL)
                    }
                }
                
                if let whatsappURL = whatsappURL {
                    Button("WhatsApp Message") {
                        UIApplication.shared.open(whatsappURL)
                    }
                }
            }
            
            Button("Delete", role: .destructive) {
                showingDeleteAlert = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Open Home", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if var schedule = viewModel.schedules[Calendar.current.startOfDay(for: openHome.startTime)] {
                    schedule.openHomes.removeAll { $0.id == openHome.id }
                    viewModel.setSchedule(schedule)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this open home?")
        }
    }
}

struct OpenHomeRouteMapView: View {
    let openHomes: [ScheduledOpenHome]
    @Environment(\.dismiss) private var dismiss
    @State private var region: MKCoordinateRegion?
    @State private var routes: [MKRoute] = []
    
    var body: some View {
        NavigationStack {
            Group {
                if let region = region {
                    MapContainerView(
                        region: region,
                        routes: routes,
                        openHomes: openHomes
                    )
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Route Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await calculateRoutes()
                fitMapToRoute()
            }
        }
    }
    
    private func calculateRoutes() async {
        let openHomes = Array(openHomes)
        
        for i in 0..<openHomes.count - 1 {
            let start = openHomes[i]
            let end = openHomes[i + 1]
            
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: start.property.coordinates))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end.property.coordinates))
            request.transportType = .automobile
            
            do {
                let directions = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MKDirections.Response, Error>) in
                    MKDirections(request: request).calculate { response, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let response = response {
                            continuation.resume(returning: response)
                        } else {
                            continuation.resume(throwing: NSError(domain: "MapError", code: -1))
                        }
                    }
                }
                
                if let route = directions.routes.first {
                    await MainActor.run {
                        routes.append(route)
                    }
                }
            } catch {
                print("Error calculating route: \(error)")
            }
        }
    }
    
    private func fitMapToRoute() {
        guard !openHomes.isEmpty else { return }
        
        let coordinates = openHomes.map { $0.property.coordinates }
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5,
            longitudeDelta: (maxLon - minLon) * 1.5
        )
        
        region = MKCoordinateRegion(center: center, span: span)
    }
}

private struct MapContainerView: View {
    let region: MKCoordinateRegion
    let routes: [MKRoute]
    let openHomes: [ScheduledOpenHome]
    @State private var position: MapCameraPosition
    
    init(region: MKCoordinateRegion, routes: [MKRoute], openHomes: [ScheduledOpenHome]) {
        self.region = region
        self.routes = routes
        self.openHomes = openHomes
        
        // Initialize position first with a default value
        _position = State(initialValue: .region(region))
        
        // Then update it with the calculated camera position
        let distance = region.span.latitudeDelta * 111000 * 1.5
        _position = State(initialValue: .camera(MapCamera(
            centerCoordinate: region.center,
            distance: distance
        )))
    }
    
    var body: some View {
        Map(position: $position) {
            // Draw routes
            ForEach(routes, id: \.self) { route in
                MapPolyline(coordinates: route.polyline.coordinates())
                    .stroke(Color.customAccent, lineWidth: 3)
            }
            
            // Draw markers
            ForEach(Array(openHomes.enumerated()), id: \.element.id) { index, openHome in
                Annotation(
                    openHome.property.streetAddress,
                    coordinate: openHome.property.coordinates
                ) {
                    Image(systemName: "\(index + 1).circle.fill")
                        .foregroundStyle(Color.customAccent)
                        .background(Circle().fill(.white))
                        .font(.title2)
                }
            }
        }
        .mapStyle(.standard)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }
}

// Helper extension to get coordinates from MKPolyline
extension MKPolyline {
    func coordinates() -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

#Preview {
    ScheduleListView(schedule: Schedule(
        date: Date(),
        openHomes: []
    ))
    .environmentObject(AppViewModel())
} 