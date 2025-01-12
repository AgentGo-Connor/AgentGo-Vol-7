import Foundation
import CoreLocation

struct Schedule: Identifiable, Codable {
    let id: UUID
    let date: Date?
    var openHomes: [ScheduledOpenHome]
    var isAutoScheduled: Bool
    
    init(id: UUID = UUID(), date: Date? = nil, openHomes: [ScheduledOpenHome] = [], isAutoScheduled: Bool = false) {
        self.id = id
        self.date = date
        self.openHomes = openHomes
        self.isAutoScheduled = isAutoScheduled
    }
} 