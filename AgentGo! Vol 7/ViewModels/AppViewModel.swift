import SwiftUI
import Combine
import CoreLocation

class AppViewModel: ObservableObject {
    @Published var properties: [Property] = []
    @Published var schedules: [Date: Schedule] = [:]
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
            setAppearance(isDarkMode)
        }
    }
    @AppStorage("defaultOpenHomeStartTime") private var defaultOpenHomeStartTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @AppStorage("defaultBufferDuration") private var defaultBufferDuration = 0
    @AppStorage("defaultOpenHomeDuration") private var defaultOpenHomeDuration = 30
    
    // Add a public getter/setter for the view
    var defaultDuration: Int {
        get { defaultOpenHomeDuration }
        set { defaultOpenHomeDuration = newValue }
    }
    
    // Add a function to get default start time for a given date
    func getDefaultStartTime(for date: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: defaultOpenHomeStartTime)
        let minute = calendar.component(.minute, from: defaultOpenHomeStartTime)
        
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }
    
    // MARK: - Property Management
    func addProperty(_ property: Property) {
        properties.append(property)
        saveProperties()
    }
    
    func updateProperty(_ property: Property) {
        if let index = properties.firstIndex(where: { $0.id == property.id }) {
            properties[index] = property
            saveProperties()
        }
    }
    
    // MARK: - Persistence
    private var propertiesURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("properties.json")
    }
    
    private var schedulesURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("schedules.json")
    }
    
    private func saveProperties() {
        do {
            let data = try JSONEncoder().encode(properties)
            try data.write(to: propertiesURL)
        } catch {
            print("Failed to save properties: \(error)")
        }
    }
    
    private func loadProperties() {
        do {
            let data = try Data(contentsOf: propertiesURL)
            properties = try JSONDecoder().decode([Property].self, from: data)
        } catch {
            print("Failed to load properties: \(error)")
            properties = []
        }
        
        do {
            let data = try Data(contentsOf: schedulesURL)
            schedules = try JSONDecoder().decode([Date: Schedule].self, from: data)
        } catch {
            print("Failed to load schedules: \(error)")
            schedules = [:]
        }
    }
    
    private func saveSchedules() {
        do {
            let data = try JSONEncoder().encode(schedules)
            try data.write(to: schedulesURL)
        } catch {
            print("Failed to save schedules: \(error)")
        }
    }
    
    // MARK: - Schedule Management
    func createAutoSchedule(date: Date, startingProperty: Property, selectedProperties: Set<Property>) {
        // Implement auto scheduling logic
    }
    
    func setSchedule(_ schedule: Schedule) {
        let startOfDay = Calendar.current.startOfDay(for: schedule.date)
        schedules[startOfDay] = schedule
        saveSchedules()
    }
    
    func resetSchedule(for date: Date) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        schedules.removeValue(forKey: startOfDay)
        saveSchedules()
    }
    
    func resetAllSchedules() {
        schedules.removeAll()
        saveSchedules()
    }
    
    func deleteProperty(_ property: Property) {
        if let index = properties.firstIndex(where: { $0.id == property.id }) {
            properties.remove(at: index)
            saveProperties()
            
            // Also remove any schedules containing this property
            for (date, schedule) in schedules {
                if schedule.openHomes.contains(where: { $0.property.id == property.id }) {
                    var updatedSchedule = schedule
                    updatedSchedule.openHomes.removeAll { $0.property.id == property.id }
                    if updatedSchedule.openHomes.isEmpty {
                        schedules.removeValue(forKey: date)
                    } else {
                        schedules[date] = updatedSchedule
                    }
                }
            }
            saveSchedules()
        }
    }
    
    private func setAppearance(_ isDark: Bool) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.overrideUserInterfaceStyle = isDark ? .dark : .light
            }
        }
    }
    
    init() {
        // Initialize dark mode from UserDefaults
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        setAppearance(isDarkMode)
        
        // Load default settings
        if let defaultStartTime = UserDefaults.standard.object(forKey: "defaultOpenHomeStartTime") as? Date {
            self.defaultOpenHomeStartTime = defaultStartTime
        }
        
        self.defaultBufferDuration = UserDefaults.standard.integer(forKey: "defaultBufferDuration")
        
        // Load saved properties and schedules
        loadProperties()
    }
    
    func roundToQuarterHour(_ date: Date) -> Date {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: date)
        let roundedMinute = (minute / 15) * 15
        
        return calendar.date(
            bySettingHour: calendar.component(.hour, from: date),
            minute: roundedMinute,
            second: 0,
            of: date
        ) ?? date
    }
}

struct ScheduledOpenHome: Identifiable, Codable, Hashable, MapSelectable {
    let id: UUID
    var property: Property
    var startTime: Date
    var endTime: Date
    var bufferBeforeStart: Date
    var bufferAfterEnd: Date
    
    // Add Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ScheduledOpenHome, rhs: ScheduledOpenHome) -> Bool {
        lhs.id == rhs.id
    }
    
    // MapSelectable conformance
    var coordinate: CLLocationCoordinate2D {
        property.coordinates
    }
} 