import Foundation

struct Schedule: Identifiable, Codable {
    let id: UUID
    var date: Date
    var openHomes: [ScheduledOpenHome]
    var isAutoScheduled: Bool
    
    init(id: UUID = UUID(), date: Date, openHomes: [ScheduledOpenHome], isAutoScheduled: Bool = true) {
        self.id = id
        self.date = date
        self.openHomes = openHomes
        self.isAutoScheduled = isAutoScheduled
    }
} 