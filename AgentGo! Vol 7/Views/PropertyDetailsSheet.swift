import SwiftUI
import UIKit

struct PropertyDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let property: Property
    @State private var propertyDetails: PropertyDetails?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var offset = CGSize.zero
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let details = propertyDetails {
                    // Main Image Placeholder
                    Rectangle()
                        .fill(Color.customAccent.opacity(0.1))
                        .overlay {
                            Image(systemName: "house.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(Color.customAccent.opacity(0.3))
                        }
                        .frame(height: 200)
                        .clipped()
                    
                    // Property Info
                    VStack(alignment: .leading, spacing: 16) {
                        // Address and Price
                        VStack(alignment: .leading, spacing: 8) {
                            Text(property.streetAddress)
                                .font(.title2.bold())
                            Text(property.suburb)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text(details.price)
                                .font(.headline)
                                .foregroundStyle(Color.customAccent)
                        }
                        .padding(.horizontal)
                        
                        // Property Features
                        HStack(spacing: 20) {
                            FeatureItem(icon: "bed.double", value: "\(property.bedrooms)", label: "Beds")
                            FeatureItem(icon: "shower", value: "\(property.bathrooms)", label: "Baths")
                            FeatureItem(icon: "car", value: "\(property.parking)", label: "Cars")
                            FeatureItem(icon: "square", value: details.landSize, label: "Land")
                        }
                        .padding(.horizontal)
                        
                        // Placeholder for future external listing button
                        Button {
                            // Reserved for future implementation
                        } label: {
                            Text("View Listing")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.customAccent.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(true)
                        .padding(.horizontal)
                        
                        // Description
                        if !details.description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.headline)
                                Text(details.description)
                                    .font(.body)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                } else if let error = error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        
                        Text("Failed to load property details")
                            .font(.headline)
                        
                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding()
                }
            }
        }
        .background(colorScheme == .dark ? Color(.systemBackground) : Color(hex: "f2efeb"))
        .offset(y: offset.height > 0 ? offset.height : 0)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: offset)
        .task {
            await loadPropertyDetails()
        }
    }
    
    private func loadPropertyDetails() async {
        isLoading = true
        do {
            propertyDetails = try await RealEstateService.fetchPropertyDetails(
                address: property.streetAddress,
                suburb: property.suburb
            )
        } catch {
            self.error = error
        }
        isLoading = false
    }
}

struct FeatureItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
