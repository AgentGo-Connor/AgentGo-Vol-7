import SwiftUI

struct PropertiesToolbar: ToolbarContent {
    @Binding var showingAddProperty: Bool
    @Binding var sortOption: AppViewModel.SortOption
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            ProfileButton()
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showingAddProperty = true
            } label: {
                Image(systemName: "plus")
            }
        }
        
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("Sort by", selection: $sortOption) {
                    Label("Street Name", systemImage: "house")
                        .tag(AppViewModel.SortOption.streetName)
                    Label("Suburb", systemImage: "mappin.and.ellipse")
                        .tag(AppViewModel.SortOption.suburb)
                    Label("Client Name", systemImage: "person")
                        .tag(AppViewModel.SortOption.clientName)
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
        }
    }
} 