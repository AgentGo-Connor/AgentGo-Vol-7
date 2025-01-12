import Foundation

struct Agent: Codable, Identifiable {
    let id: String
    var name: String
    var email: String
    var phoneNumber: String
    var licenseNumber: String
    var agencyName: String
    var agencyAddress: String
    var photoURL: String?
} 