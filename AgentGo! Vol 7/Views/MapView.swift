import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedProperty: Property?
    @State private var showingPropertyDetails = false
    @State private var showsUserLocation = true
    @State private var visibleProperties: [Property] = []
    @State private var isUpdatingProperties = false
    @State private var lastUpdateTime: Date = Date()
    @State private var updateWorkItem: DispatchWorkItem?
    @Environment(\.colorScheme) private var colorScheme
    
    private let updateThrottleInterval: TimeInterval = 0.5
    private let updateQueue = DispatchQueue(label: "com.agentgo.mapupdate", qos: .userInitiated)
    
    var body: some View {
        NavigationStack {
            ZStack {
                MapContentView(
                    position: $position,
                    selectedProperty: $selectedProperty,
                    showingPropertyDetails: $showingPropertyDetails,
                    visibleProperties: $visibleProperties
                )
                .onChange(of: viewModel.properties) { _, newProperties in
                    queuePropertyUpdate(from: newProperties)
                }
                .onChange(of: position) { _, _ in
                    queuePropertyUpdate(from: viewModel.properties)
                }
                .onDisappear {
                    // Cancel any pending updates
                    updateWorkItem?.cancel()
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    ProfileButton()
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                
                MapToolbarContent(centerMapAction: centerMapOnProperties)
            }
        }
    }
    
    private func queuePropertyUpdate(from properties: [Property]) {
        // Cancel any pending update
        updateWorkItem?.cancel()
        
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) >= updateThrottleInterval else { return }
        
        // Create new work item
        let workItem = DispatchWorkItem { [properties] in
            guard !isUpdatingProperties else { return }
            isUpdatingProperties = true
            lastUpdateTime = now
            
            // Perform update on background queue
            updateQueue.async {
                let updatedProperties = calculateVisibleProperties(from: properties)
                
                // Update UI on main queue
                DispatchQueue.main.async {
                    visibleProperties = updatedProperties
                    isUpdatingProperties = false
                }
            }
        }
        
        // Store reference to work item
        updateWorkItem = workItem
        
        // Schedule work item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
    
    private func calculateVisibleProperties(from properties: [Property]) -> [Property] {
        guard let region = position.region else { 
            return properties
        }
        
        let padding: Double = 1.5
        let minLat = region.center.latitude - (region.span.latitudeDelta * padding)
        let maxLat = region.center.latitude + (region.span.latitudeDelta * padding)
        let minLon = region.center.longitude - (region.span.longitudeDelta * padding)
        let maxLon = region.center.longitude + (region.span.longitudeDelta * padding)
        
        return properties.filter { property in
            let lat = property.coordinates.latitude
            let lon = property.coordinates.longitude
            return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon
        }
    }
    
    private func centerMapOnProperties() {
        guard !viewModel.properties.isEmpty else { return }
        
        // Calculate bounds on background queue
        updateQueue.async {
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
            
            // Update UI on main queue
            DispatchQueue.main.async {
                withAnimation(.easeInOut) {
                    position = .region(MKCoordinateRegion(center: center, span: span))
                }
                
                // Queue property update after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    queuePropertyUpdate(from: viewModel.properties)
                }
            }
        }
    }
    
    private func getNextOpenHome() -> ScheduledOpenHome? {
        let today = Calendar.current.startOfDay(for: Date())
        return viewModel.schedules[today]?.openHomes.first { openHome in
            openHome.startTime > Date()
        }
    }
}

private struct MapContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Binding var position: MapCameraPosition
    @Binding var selectedProperty: Property?
    @Binding var showingPropertyDetails: Bool
    @Binding var visibleProperties: [Property]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position, selection: $selectedProperty) {
                ForEach(visibleProperties) { property in
                    Annotation(property.streetAddress, coordinate: property.coordinates) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundStyle(Color.customAccent)
                            .background(Color.white.clipShape(Circle()))
                    }
                    .tag(property)
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            
            if let nextOpenHome = getNextOpenHome() {
                NavigationButton(openHome: nextOpenHome)
                    .padding()
                    .padding(.bottom, 60)
            }
        }
        .sheet(
            item: $selectedProperty,
            onDismiss: { selectedProperty = nil }
        ) { property in
            PropertyDetailsSheet(property: property)
                .presentationDetents([.height(UIScreen.main.bounds.height * 0.9)])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
                .presentationCornerRadius(25)
                .interactiveDismissDisabled(false)
        }
    }
    
    private func getNextOpenHome() -> ScheduledOpenHome? {
        let today = Calendar.current.startOfDay(for: Date())
        return viewModel.schedules[today]?.openHomes.first { openHome in
            openHome.startTime > Date()
        }
    }
}

private struct MapViewContent: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Binding var position: MapCameraPosition
    @Binding var selectedProperty: Property?
    @Binding var showingPropertyDetails: Bool
    
    var body: some View {
        Map(position: $position, selection: $selectedProperty) {
            ForEach(viewModel.properties) { property in
                Annotation(property.streetAddress, coordinate: property.coordinates) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundStyle(Color.customAccent)
                        .background(Color.white.clipShape(Circle()))
                }
                .tag(property)
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onChange(of: selectedProperty) { _, newValue in
            withAnimation {
                showingPropertyDetails = newValue != nil
            }
        }
    }
}

private struct MapToolbarContent: ToolbarContent {
    let centerMapAction: () -> Void
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                withAnimation {
                    centerMapAction()
                }
            } label: {
                Image(systemName: "map.circle")
                    .foregroundStyle(Color.customAccent)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
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
