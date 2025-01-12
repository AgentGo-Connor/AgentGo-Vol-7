import SwiftUI
import MapKit
import CoreLocation

struct RouteMapView: View {
    let schedule: Schedule
    
    @State private var position: MapCameraPosition = .automatic
    @State private var routes: [MKRoute] = []
    @State private var selectedOpenHome: ScheduledOpenHome?
    
    var body: some View {
        Map(position: $position, selection: $selectedOpenHome) {
            // Property markers
            ForEach(schedule.openHomes) { openHome in
                Marker(openHome.property.streetAddress, coordinate: openHome.property.coordinates)
                    .tint(Color.accentColor)
                    .tag(openHome)
            }
            
            // Route polylines
            ForEach(routes, id: \.self) { route in
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 3)
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .overlay(alignment: .bottom) {
            if let selected = selectedOpenHome {
                OpenHomeInfoCard(openHome: selected)
                    .padding()
            }
        }
        .onAppear {
            calculateRoutes()
            centerMapOnRoute()
        }
    }
    
    private func calculateRoutes() {
        guard schedule.openHomes.count > 1 else { return }
        
        Task {
            var newRoutes: [MKRoute] = []
            
            // Calculate routes between consecutive properties
            for i in 0..<schedule.openHomes.count-1 {
                let start = schedule.openHomes[i].property.coordinates
                let end = schedule.openHomes[i+1].property.coordinates
                
                if let route = await calculateRoute(from: start, to: end) {
                    newRoutes.append(route)
                }
            }
            
            await MainActor.run {
                routes = newRoutes
            }
        }
    }
    
    private func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> MKRoute? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        
        do {
            let response = try await MKDirections(request: request).calculate()
            return response.routes.first
        } catch {
            print("Failed to calculate route: \(error)")
            return nil
        }
    }
    
    private func centerMapOnRoute() {
        guard !schedule.openHomes.isEmpty else { return }
        
        let coordinates = schedule.openHomes.map { $0.property.coordinates }
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
        
        position = .region(MKCoordinateRegion(center: center, span: span))
    }
}

struct OpenHomeInfoCard: View {
    let openHome: ScheduledOpenHome
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(openHome.property.streetAddress)
                .font(.headline)
            Text(openHome.property.suburb)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text(openHome.startTime, format: .dateTime.hour().minute())
                Text("-")
                Text(openHome.endTime, format: .dateTime.hour().minute())
            }
            .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    RouteMapView(schedule: Schedule(
        date: Date(),
        openHomes: []
    ))
} 