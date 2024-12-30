import SwiftUI
import MapKit
import CoreLocation

struct TravelTimeView: View {
    let from: ScheduledOpenHome
    let to: ScheduledOpenHome
    @State private var travelTime: TimeInterval?
    @State private var distance: Double?
    
    var body: some View {
        HStack {
            Image(systemName: "arrow.down")
                .foregroundStyle(.secondary)
            
            if let travelTime = travelTime, let distance = distance {
                Text("\(Int(travelTime / 60)) min (\(Int(distance / 1000)) km)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Calculating...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            calculateRoute()
        }
    }
    
    private func calculateRoute() {
        let request = MKDirections.Request()
        let fromPlacemark = MKPlacemark(coordinate: from.property.coordinates)
        let toPlacemark = MKPlacemark(coordinate: to.property.coordinates)
        
        request.source = MKMapItem(placemark: fromPlacemark)
        request.destination = MKMapItem(placemark: toPlacemark)
        
        Task {
            do {
                let directions = MKDirections(request: request)
                let response = try await directions.calculate()
                if let route = response.routes.first {
                    await MainActor.run {
                        self.travelTime = route.expectedTravelTime
                        self.distance = route.distance
                    }
                }
            } catch {
                print("Failed to calculate route: \(error)")
            }
        }
    }
} 