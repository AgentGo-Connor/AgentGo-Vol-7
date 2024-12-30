import SwiftUI
import MapKit
import CoreLocation

struct PropertyFormView: View {
    enum Mode: Equatable {
        case add
        case edit(Property)
        
        var isEditing: Bool {
            if case .edit = self {
                return true
            }
            return false
        }
    }
    
    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel
    
    @State private var streetAddress = ""
    @State private var suburb = ""
    @State private var clientFirstName = ""
    @State private var clientLastName = ""
    @State private var clientPhone = ""
    @State private var openHomeDuration: Int
    @State private var bufferBefore = 5
    @State private var bufferAfter = 5
    @State private var selectedLocation: CLLocationCoordinate2D?
    
    private var editingProperty: Property? {
        if case let .edit(property) = mode {
            return property
        }
        return nil
    }
    
    init(mode: Mode) {
        self.mode = mode
        _openHomeDuration = State(initialValue: AppViewModel().defaultDuration)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Street Address", text: $streetAddress)
                        .textContentType(.streetAddressLine1)
                    
                    TextField("Suburb", text: $suburb)
                        .textContentType(.addressCity)
                    
                    // Add map preview here if selectedLocation exists
                    if let location = selectedLocation {
                        Map(position: .constant(.region(MKCoordinateRegion(
                            center: location,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )))) {
                            Marker("Selected Location", coordinate: location)
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button("Search Address") {
                        searchAddress()
                    }
                } header: {
                    Text("Address")
                }
                
                Section {
                    TextField("First Name", text: $clientFirstName)
                        .textContentType(.givenName)
                    
                    TextField("Last Name", text: $clientLastName)
                        .textContentType(.familyName)
                    
                    TextField("Phone", text: $clientPhone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                } header: {
                    Text("Client Details")
                }
                
                Section {
                    Picker("Duration", selection: $openHomeDuration) {
                        ForEach([15, 30, 45, 60, 75, 90], id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                    
                    Picker("Buffer Before", selection: $bufferBefore) {
                        Text("No Buffer").tag(0)
                        ForEach(Array(stride(from: 5, through: 30, by: 5)), id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                    
                    Picker("Buffer After", selection: $bufferAfter) {
                        Text("No Buffer").tag(0)
                        ForEach(Array(stride(from: 5, through: 30, by: 5)), id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                } header: {
                    Text("Open Home Details")
                } footer: {
                    Text("Buffer times help ensure you have enough time to travel between properties.")
                }
            }
            .navigationTitle(mode == .add ? "Add Property" : "Edit Property")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProperty()
                    }
                    .disabled(!canSave)
                    .foregroundStyle(Color.customAccent)
                }
            }
            .onAppear {
                if let property = editingProperty {
                    streetAddress = property.streetAddress
                    suburb = property.suburb
                    clientFirstName = property.clientFirstName
                    clientLastName = property.clientLastName
                    clientPhone = property.clientPhone
                    openHomeDuration = property.openHomeDuration
                    bufferBefore = property.bufferBefore
                    bufferAfter = property.bufferAfter
                    selectedLocation = property.coordinates
                }
            }
        }
    }
    
    private var canSave: Bool {
        !streetAddress.isEmpty && !suburb.isEmpty && selectedLocation != nil
    }
    
    private func saveProperty() {
        guard let location = selectedLocation else { return }
        
        let property = Property(
            id: editingProperty?.id ?? UUID(),
            streetAddress: streetAddress,
            suburb: suburb,
            coordinates: location,
            clientFirstName: clientFirstName,
            clientLastName: clientLastName,
            clientPhone: clientPhone,
            openHomeDuration: openHomeDuration,
            bufferBefore: bufferBefore,
            bufferAfter: bufferAfter
        )
        
        if mode.isEditing {
            viewModel.updateProperty(property)
        } else {
            viewModel.addProperty(property)
        }
        
        dismiss()
    }
    
    private func searchAddress() {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "\(streetAddress), \(suburb)"
        searchRequest.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -27.4705, longitude: 153.0260), // Brisbane
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        
        MKLocalSearch(request: searchRequest).start { response, error in
            if let place = response?.mapItems.first {
                selectedLocation = place.placemark.coordinate
                streetAddress = place.name ?? streetAddress
                suburb = place.placemark.locality ?? suburb
            }
        }
    }
} 