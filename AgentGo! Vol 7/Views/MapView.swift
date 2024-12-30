import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedProperty: Property?
    @State private var showingNavigationSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $position, selection: $selectedProperty) {
                    ForEach(viewModel.properties) { property in
                        Marker(property.streetAddress, coordinate: property.coordinates)
                            .tint(Color.customAccent)
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                
                // Navigation Button
                if let nextOpenHome = getNextOpenHome() {
                    NavigationButton(openHome: nextOpenHome)
                        .padding()
                        .padding(.bottom, 60) // Add extra padding for tab bar
                }
            }
            .navigationTitle("Map")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation {
                            centerMapOnProperties()
                        }
                    } label: {
                        Image(systemName: "map.circle")
                            .foregroundStyle(Color.customAccent)
                    }
                }
            }
        }
    }
    
    private func centerMapOnProperties() {
        guard !viewModel.properties.isEmpty else { return }
        
        let coordinates = viewModel.properties.map { $0.coordinates }
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
    
    private func getNextOpenHome() -> ScheduledOpenHome? {
        let today = Calendar.current.startOfDay(for: Date())
        return viewModel.schedules[today]?.openHomes.first { openHome in
            openHome.startTime > Date()
        }
    }
}

struct NavigationButton: View {
    let openHome: ScheduledOpenHome
    @State private var showingNavigationSheet = false
    
    var body: some View {
        Button {
            showingNavigationSheet = true
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    if openHome.startTime > Date() {
                        Text("Next Open Home Starting in \(Int(openHome.startTime.timeIntervalSince(Date()) / 60)) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Open Home")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(openHome.property.streetAddress)
                        .font(.headline)
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text(openHome.startTime, format: .dateTime.hour().minute())
                    }
                    .font(.caption)
                }
                Spacer()
                Circle()
                    .fill(Color.customAccent)
                    .frame(width: 65, height: 65)
                    .overlay {
                        Text("Go!")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingNavigationSheet) {
            NavigationActionSheet(property: openHome.property)
        }
    }
}

struct NavigationActionSheet: View {
    let property: Property
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Button {
                    openInMaps(using: "maps://")
                } label: {
                    Label("Apple Maps", systemImage: "map")
                }
                
                Button {
                    openInGoogleMaps()
                } label: {
                    Label("Google Maps", systemImage: "map")
                }
            }
            .navigationTitle("Navigate using")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(200)])
    }
    
    private func openInMaps(using urlScheme: String) {
        let address = "\(property.streetAddress), \(property.suburb)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let mapsURL = "\(urlScheme)?q=\(address)"
        
        if let url = URL(string: mapsURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        dismiss()
    }
    
    private func openInGoogleMaps() {
        let address = "\(property.streetAddress), \(property.suburb)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Try to open in Google Maps app first
        let googleMapsURL = "comgooglemaps://?q=\(address)&directionsmode=driving"
        if let url = URL(string: googleMapsURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // If Google Maps isn't installed, open in browser
            let webURL = "https://www.google.com/maps/search/?api=1&query=\(address)"
            if let url = URL(string: webURL) {
                UIApplication.shared.open(url)
            }
        }
        dismiss()
    }
}

#Preview {
    MapView()
        .environmentObject(AppViewModel())
} 
