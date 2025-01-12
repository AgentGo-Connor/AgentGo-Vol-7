import SwiftUI

struct PropertyCard: View {
    let property: Property
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(property.streetAddress)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(property.suburb)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("\(property.clientFirstName) \(property.clientLastName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceFor(colorScheme: colorScheme))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderFor(colorScheme: colorScheme), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
} 