import Foundation

class AnalyticsService {
    static let shared = AnalyticsService()
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    func logEvent(_ name: String, parameters: [String: Any]? = nil) async {
        #if DEBUG
        print("Analytics Event: \(name)")
        if let parameters = parameters {
            print("Parameters: \(parameters)")
        }
        #endif
        
        // Store events locally for now
        var events = defaults.array(forKey: "analytics_events") as? [[String: Any]] ?? []
        var event: [String: Any] = ["name": name, "timestamp": Date()]
        if let parameters = parameters {
            event["parameters"] = parameters
        }
        events.append(event)
        defaults.set(events, forKey: "analytics_events")
    }
} 