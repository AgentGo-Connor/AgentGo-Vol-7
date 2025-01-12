import Foundation

class RealEstateService {
    static let shared = RealEstateService()
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    func createAgent(_ agent: Agent) async throws {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(agent) {
            defaults.set(encoded, forKey: "agent_\(agent.id)")
        }
    }
    
    func getAgent(id: String) async throws -> Agent {
        guard let data = defaults.data(forKey: "agent_\(id)"),
              let agent = try? JSONDecoder().decode(Agent.self, from: data) else {
            throw RealEstateError.agentNotFound
        }
        return agent
    }
    
    func updateAgent(_ agent: Agent) async throws {
        try await createAgent(agent)
    }
    
    static func fetchPropertyDetails(address: String, suburb: String) async throws -> PropertyDetails {
        // Return basic property details without Domain integration
        return PropertyDetails(
            mainImageURL: nil,
            price: "Contact Agent",
            bedrooms: 0,
            bathrooms: 0,
            parkingSpaces: 0,
            landSize: "Not Available",
            description: "Property details will be available soon."
        )
    }
}

enum RealEstateError: LocalizedError {
    case agentNotFound
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .agentNotFound:
            return "Agent profile not found"
        case .notImplemented:
            return "This feature is not yet implemented"
        }
    }
} 
