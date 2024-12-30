import SwiftUI
import MapKit
import CoreLocation

struct PropertiesView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showingAddProperty = false
    @State private var selectedProperty: Property?
    @State private var showingDeleteAlert = false
    @State private var propertyToDelete: Property?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.properties) { property in
                    PropertyRow(property: property)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedProperty = property
                        }
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        propertyToDelete = viewModel.properties[index]
                        showingDeleteAlert = true
                    }
                }
            }
            .navigationTitle("Properties")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddProperty = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddProperty) {
                PropertyFormView(mode: .add)
            }
            .sheet(item: $selectedProperty) { property in
                PropertyFormView(mode: .edit(property))
            }
            .alert("Delete Property", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    propertyToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let property = propertyToDelete {
                        withAnimation {
                            viewModel.deleteProperty(property)
                        }
                    }
                    propertyToDelete = nil
                }
            } message: {
                if let property = propertyToDelete {
                    Text("Are you sure you want to delete \(property.streetAddress)? This will also remove any scheduled open homes for this property.")
                }
            }
        }
    }
}

struct PropertyRow: View {
    let property: Property
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(property.streetAddress)
                .font(.headline)
            Text(property.suburb)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if !property.clientFirstName.isEmpty {
                HStack {
                    Image(systemName: "person")
                        .foregroundStyle(.secondary)
                    Text("\(property.clientFirstName) \(property.clientLastName)")
                        .font(.caption)
                }
            }
            
            if !property.clientPhone.isEmpty {
                HStack {
                    Image(systemName: "phone")
                        .foregroundStyle(.secondary)
                    Text(property.clientPhone)
                        .font(.caption)
                }
            }
            
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text("Open Home: \(property.openHomeDuration) min")
                    .font(.caption)
                Text("Buffer: \(property.bufferBefore)/\(property.bufferAfter) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PropertiesView()
        .environmentObject(AppViewModel())
} 