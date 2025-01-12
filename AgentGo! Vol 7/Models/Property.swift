import Foundation
import CoreLocation

struct Property: Identifiable, Codable, Hashable {
    let id: UUID
    var streetAddress: String
    var suburb: String
    var coordinates: CLLocationCoordinate2D
    var clientFirstName: String
    var clientLastName: String
    var clientPhone: String
    var openHomeDuration: Int // in minutes
    var bufferBefore: Int // in minutes
    var bufferAfter: Int // in minutes
    var bedrooms: Int
    var bathrooms: Int
    var parking: Int
    var imageURL: URL?
    
    init(id: UUID = UUID(), 
         streetAddress: String, 
         suburb: String, 
         coordinates: CLLocationCoordinate2D, 
         clientFirstName: String = "", 
         clientLastName: String = "", 
         clientPhone: String = "", 
         openHomeDuration: Int = 30, 
         bufferBefore: Int = 5, 
         bufferAfter: Int = 5,
         bedrooms: Int = 0,
         bathrooms: Int = 0,
         parking: Int = 0,
         imageURL: URL? = nil) {
        
        self.id = id
        self.streetAddress = streetAddress
        self.suburb = suburb
        self.coordinates = coordinates
        self.clientFirstName = clientFirstName
        self.clientLastName = clientLastName
        self.clientPhone = clientPhone
        self.openHomeDuration = openHomeDuration
        self.bufferBefore = bufferBefore
        self.bufferAfter = bufferAfter
        self.bedrooms = bedrooms
        self.bathrooms = bathrooms
        self.parking = parking
        self.imageURL = imageURL
    }
    
    // Add custom decoding init to handle missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        streetAddress = try container.decode(String.self, forKey: .streetAddress)
        suburb = try container.decode(String.self, forKey: .suburb)
        coordinates = try container.decode(CLLocationCoordinate2D.self, forKey: .coordinates)
        
        // Optional fields with default values
        clientFirstName = try container.decodeIfPresent(String.self, forKey: .clientFirstName) ?? ""
        clientLastName = try container.decodeIfPresent(String.self, forKey: .clientLastName) ?? ""
        clientPhone = try container.decodeIfPresent(String.self, forKey: .clientPhone) ?? ""
        openHomeDuration = try container.decodeIfPresent(Int.self, forKey: .openHomeDuration) ?? 30
        bufferBefore = try container.decodeIfPresent(Int.self, forKey: .bufferBefore) ?? 5
        bufferAfter = try container.decodeIfPresent(Int.self, forKey: .bufferAfter) ?? 5
        bedrooms = try container.decodeIfPresent(Int.self, forKey: .bedrooms) ?? 0
        bathrooms = try container.decodeIfPresent(Int.self, forKey: .bathrooms) ?? 0
        parking = try container.decodeIfPresent(Int.self, forKey: .parking) ?? 0
        imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
    }
    
    // Add Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Property, rhs: Property) -> Bool {
        lhs.id == rhs.id
    }
    
    var coordinate: CLLocationCoordinate2D {
        coordinates
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case streetAddress
        case suburb
        case coordinates
        case clientFirstName
        case clientLastName
        case clientPhone
        case openHomeDuration
        case bufferBefore
        case bufferAfter
        case bedrooms
        case bathrooms
        case parking
        case imageURL
    }
}

// Extension to make CLLocationCoordinate2D codable
extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
} 