import SwiftUI

struct PropertyListView: View {
    let properties: [Property]
    @Binding var selectedLetter: String?
    let onPropertyTap: (Property) -> Void
    let onDeleteTap: (Property) -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(groupedProperties.keys.sorted(), id: \.self) { letter in
                    Section(header: Text(letter)) {
                        ForEach(groupedProperties[letter] ?? []) { property in
                            PropertyCard(property: property)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .onTapGesture {
                                    onPropertyTap(property)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        onDeleteTap(property)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .id(letter)
                }
            }
            .listStyle(.plain)
            .onChange(of: selectedLetter) { letter in
                if let letter = letter {
                    withAnimation {
                        proxy.scrollTo(letter, anchor: .top)
                    }
                }
            }
        }
    }
    
    private var groupedProperties: [String: [Property]] {
        Dictionary(grouping: properties) { property in
            String(property.streetAddress.prefix(1).uppercased())
        }
    }
} 