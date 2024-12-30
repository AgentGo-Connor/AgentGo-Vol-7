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
    
    init(id: UUID = UUID(), streetAddress: String, suburb: String, coordinates: CLLocationCoordinate2D, 
         clientFirstName: String = "", clientLastName: String = "", clientPhone: String = "", 
         openHomeDuration: Int = 30, bufferBefore: Int = 5, bufferAfter: Int = 5) {
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
    }
    
    // Add Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Property, rhs: Property) -> Bool {
        lhs.id == rhs.id
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