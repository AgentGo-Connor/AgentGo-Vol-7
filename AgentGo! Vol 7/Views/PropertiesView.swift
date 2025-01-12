import SwiftUI

struct PropertiesView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showingAddProperty = false
    @State private var selectedProperty: Property?
    @State private var showingDeleteAlert = false
    @State private var propertyToDelete: Property?
    @State private var showingSortOptions = false
    @State private var selectedLetter: String? = nil
    @State private var showLetterOverlay = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            PropertiesContentView(
                properties: sortedProperties,
                selectedLetter: $selectedLetter,
                showLetterOverlay: $showLetterOverlay,
                sectionLetters: sectionLetters,
                onPropertySelect: { selectedProperty = $0 },
                onDeleteRequest: {
                    propertyToDelete = $0
                    showingDeleteAlert = true
                }
            )
            .background(colorScheme == .dark ? Color.customDarkBackground : Color.customLightBackground)
            .toolbarBackground(colorScheme == .dark ? Color.customDarkBackground : Color.customLightBackground, for: .navigationBar)
            .toolbar {
                PropertiesToolbar(
                    showingAddProperty: $showingAddProperty,
                    sortOption: Binding(
                        get: { viewModel.sortOption },
                        set: { viewModel.sortOption = $0 }
                    )
                )
            }
            .sheet(isPresented: $showingAddProperty) {
                PropertyFormView(mode: .add)
            }
            .sheet(item: $selectedProperty) { property in
                PropertyDetailsSheet(property: property)
            }
            .alert("Delete Property", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let property = propertyToDelete {
                        viewModel.deleteProperty(property)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this property?")
            }
        }
    }
    
    var sortedProperties: [Property] {
        viewModel.properties.sorted { first, second in
            switch viewModel.sortOption {
            case .streetName:
                let firstStreet = viewModel.getStreetName(first.streetAddress)
                let secondStreet = viewModel.getStreetName(second.streetAddress)
                return firstStreet.localizedCompare(secondStreet) == .orderedAscending
            case .suburb:
                return first.suburb.localizedCompare(second.suburb) == .orderedAscending
            case .clientName:
                return first.clientFirstName.localizedCompare(second.clientFirstName) == .orderedAscending
            }
        }
    }
    
    private var sectionLetters: [String] {
        let properties = sortedProperties
        switch viewModel.sortOption {
        case .streetName:
            return Array(Set(properties.map { viewModel.getStreetName($0.streetAddress).prefix(1).uppercased() })).sorted()
        case .suburb:
            return Array(Set(properties.map { $0.suburb.prefix(1).uppercased() })).sorted()
        case .clientName:
            return Array(Set(properties.map { $0.clientFirstName.prefix(1).uppercased() })).sorted()
        }
    }
}

#Preview {
    PropertiesView()
        .environmentObject(AppViewModel())
} 
