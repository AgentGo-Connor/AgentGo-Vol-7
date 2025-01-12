import Foundation
import SwiftUI

struct PropertyDetails: Codable {
    var mainImageURL: URL?
    var price: String
    var bedrooms: Int
    var bathrooms: Int
    var parkingSpaces: Int
    var landSize: String
    var description: String
    var listingURL: URL?  // Generic URL for future use
    
    init(
        mainImageURL: URL? = nil,
        price: String = "Contact Agent",
        bedrooms: Int = 0,
        bathrooms: Int = 0,
        parkingSpaces: Int = 0,
        landSize: String = "Not Available",
        description: String = "",
        listingURL: URL? = nil
    ) {
        self.mainImageURL = mainImageURL
        self.price = price
        self.bedrooms = bedrooms
        self.bathrooms = bathrooms
        self.parkingSpaces = parkingSpaces
        self.landSize = landSize
        self.description = description
        self.listingURL = listingURL
    }
} 