import SwiftUI
import Combine
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import FirebaseDynamicLinks
import BranchSDK
import FirebaseFunctions
import FirebaseStorage
import PhotosUI

// Add TeamManager class definition
class TeamManager: ObservableObject {
    private let db = Firestore.firestore()
    @Published var currentTeam: Team?
    @Published var teamMembers: [TeamMember] = []
    @Published var pendingInvites: [TeamInvite] = []
    
    struct Team: Identifiable, Codable {
        let id: String
        let name: String
        let ownerUID: String
        let createdAt: Date
    }
    
    struct TeamMember: Identifiable, Codable {
        let id: String // User UID
        let email: String
        let role: TeamRole
        let joinedAt: Date
    }
    
    struct TeamInvite: Identifiable, Codable {
        let id: String
        let teamId: String
        let inviterEmail: String
        let inviteeEmail: String
        let status: InviteStatus
        let createdAt: Date
        let expiresAt: Date
    }
    
    enum TeamRole: String, Codable {
        case owner
        case member
    }
    
    enum InviteStatus: String, Codable {
        case pending
        case accepted
        case declined
        case expired
    }
    
    // Generate a unique invite link
    func generateInviteLink(for email: String) async throws -> URL {
        print("Starting generateInviteLink for email: \(email)")
        
        guard let currentTeam = currentTeam,
              let currentUser = Auth.auth().currentUser else {
            print("Error: No team or user found")
            throw TeamError.noTeamOrUser
        }
        
        print("Creating invite object...")
        let invite = TeamInvite(
            id: UUID().uuidString,
            teamId: currentTeam.id,
            inviterEmail: currentUser.email ?? "",
            inviteeEmail: email,
            status: .pending,
            createdAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        )
        
        print("Saving invite to Firestore...")
        // Save invite to Firestore
        try await db.collection("teamInvites").document(invite.id).setData([
            "id": invite.id,
            "teamId": invite.teamId,
            "inviterEmail": invite.inviterEmail,
            "inviteeEmail": invite.inviteeEmail,
            "status": invite.status.rawValue,
            "createdAt": invite.createdAt,
            "expiresAt": invite.expiresAt,
            "teamName": currentTeam.name // Add team name for email template
        ])
        
        print("Generating Branch link...")
        // Generate Branch link
        let url = try await BranchService.shared.createTeamInviteLink(
            inviteId: invite.id,
            teamId: invite.teamId
        )
        
        // Call Firebase function to send email
        let functions = Functions.functions(region: "australia-southeast1")
        let data: [String: Any] = [
            "inviteeEmail": email,
            "inviterEmail": currentUser.email ?? "",
            "teamName": currentTeam.name,
            "inviteLink": url.absoluteString,
            "inviteId": invite.id,
            "teamId": invite.teamId
        ]
        
        print("Sending email via Firebase function...")
        do {
            let result = try await functions.httpsCallable("sendTeamInviteEmail").call(data)
            print("Email sent successfully:", result.data)
        } catch {
            print("Error sending email:", error)
            throw TeamError.emailSendFailed
        }
        
        print("Returning generated URL")
        return url
    }
    
    // Accept an invite
    func acceptInvite(inviteId: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw TeamError.noTeamOrUser
        }
        
        let inviteRef = db.collection("teamInvites").document(inviteId)
        let invite = try await inviteRef.getDocument(as: TeamInvite.self)
        
        guard invite.status == .pending && invite.expiresAt > Date() else {
            throw TeamError.invalidInvite
        }
        
        // Update invite status
        try await inviteRef.updateData([
            "status": InviteStatus.accepted.rawValue
        ])
        
        // Add user to team
        let teamRef = db.collection("teams").document(invite.teamId)
        try await teamRef.collection("members").document(currentUser.uid).setData([
            "id": currentUser.uid,
            "email": currentUser.email ?? "",
            "role": TeamRole.member.rawValue,
            "joinedAt": Date()
        ])
        
        // Update local state
        await loadTeamData(teamId: invite.teamId)
    }
    
    // Load team data
    func loadTeamData(teamId: String) async {
        do {
            let teamDoc = try await db.collection("teams").document(teamId).getDocument()
            currentTeam = try teamDoc.data(as: Team.self)
            
            let membersSnapshot = try await db.collection("teams")
                .document(teamId)
                .collection("members")
                .getDocuments()
            
            teamMembers = membersSnapshot.documents.compactMap { doc -> TeamMember? in
                try? doc.data(as: TeamMember.self)
            }
            
            // Listen for team changes
            setupTeamListener(teamId: teamId)
        } catch {
            print("Error loading team data: \(error)")
        }
    }
    
    private func setupTeamListener(teamId: String) {
        db.collection("teams")
            .document(teamId)
            .collection("members")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching team members: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.teamMembers = documents.compactMap { doc -> TeamMember? in
                    try? doc.data(as: TeamMember.self)
                }
            }
    }
    
    enum TeamError: Error {
        case noTeamOrUser
        case invalidInvite
        case teamNotFound
        case emailSendFailed
    }
    
    func createTeam(name: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw TeamError.noTeamOrUser
        }
        
        let teamId = UUID().uuidString
        let team = Team(
            id: teamId,
            name: name,
            ownerUID: currentUser.uid,
            createdAt: Date()
        )
        
        // Create team document
        try await db.collection("teams").document(teamId).setData([
            "id": team.id,
            "name": team.name,
            "ownerUID": team.ownerUID,
            "createdAt": team.createdAt
        ])
        
        // Add owner as first team member
        let owner = TeamMember(
            id: currentUser.uid,
            email: currentUser.email ?? "",
            role: .owner,
            joinedAt: Date()
        )
        
        try await db.collection("teams")
            .document(teamId)
            .collection("members")
            .document(currentUser.uid)
            .setData([
                "id": owner.id,
                "email": owner.email,
                "role": owner.role.rawValue,
                "joinedAt": owner.joinedAt
            ])
        
        // Update local state
        currentTeam = team
        teamMembers = [owner]
        
        // Setup listener for this team
        setupTeamListener(teamId: teamId)
    }
    
    func createInviteLink(inviteId: String, teamId: String) async throws -> URL {
        return try await BranchService.shared.createTeamInviteLink(inviteId: inviteId, teamId: teamId)
    }
}

class AppViewModel: ObservableObject {
    @Published var properties: [Property] = []
    @Published var sortOption: SortOption = .streetName
    @Published var schedules: [Date: Schedule] = [:]
    @Published var selectedProperty: Property?
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
            setAppearance(isDarkMode)
        }
    }
    @AppStorage("defaultOpenHomeStartTime") private var defaultOpenHomeStartTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @AppStorage("defaultBufferDuration") private var defaultBufferDuration = 0
    @AppStorage("defaultOpenHomeDuration") private var defaultOpenHomeDuration = 30
    @Published var teamManager = TeamManager()
    private let db = Firestore.firestore()
    @Published var currentUser: User?
    private var authStateListener: AuthStateDidChangeListenerHandle?
    @Published var userProfileImage: UIImage?
    @Published var selectedItem: PhotosPickerItem? {
        didSet {
            Task {
                if let data = try? await selectedItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    try? await uploadProfileImage(image)
                }
            }
        }
    }
    private let storage = Storage.storage(url: "gs://agentgo-d605c.firebasestorage.app")
    
    deinit {
        // Remove the auth state listener when the view model is deallocated
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // Add a public getter/setter for the view
    var defaultDuration: Int {
        get { defaultOpenHomeDuration }
        set { defaultOpenHomeDuration = newValue }
    }
    
    // Add a public getter for defaultBufferDuration
    var defaultBuffer: Int {
        get { defaultBufferDuration }
        set { defaultBufferDuration = newValue }
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
        savePropertyToFirebase(property)
    }
    
    func updateProperty(_ property: Property) {
        if let index = properties.firstIndex(where: { $0.id == property.id }) {
            properties[index] = property
            saveProperties()
            savePropertyToFirebase(property)
            
            // Update any schedules containing this property
            for (date, schedule) in schedules {
                if schedule.openHomes.contains(where: { $0.property.id == property.id }) {
                    var updatedSchedule = schedule
                    updatedSchedule.openHomes = schedule.openHomes.map { openHome in
                        if openHome.property.id == property.id {
                            return ScheduledOpenHome(
                                id: openHome.id,
                                property: property,
                                startTime: openHome.startTime,
                                endTime: openHome.endTime,
                                bufferBeforeStart: openHome.bufferBeforeStart,
                                bufferAfterEnd: openHome.bufferAfterEnd
                            )
                        }
                        return openHome
                    }
                    schedules[date] = updatedSchedule
                    saveSchedules()
                    saveScheduleToFirebase(updatedSchedule, for: date)
                }
            }
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
        guard let date = schedule.date else { return }
        let startOfDay = Calendar.current.startOfDay(for: date)
        schedules[startOfDay] = schedule
        saveSchedules()
        saveScheduleToFirebase(schedule, for: startOfDay)
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
        if let index = properties.firstIndex(of: property) {
            properties.remove(at: index)
            saveProperties()
            
            // Delete from Firebase
            guard let userId = Auth.auth().currentUser?.uid else { return }
            db.collection("users").document(userId)
                .collection("properties").document(property.id.uuidString)
                .delete { error in
                    if let error = error {
                        print("Error deleting property from Firebase: \(error)")
                    } else {
                        print("Successfully deleted property from Firebase")
                    }
                }
            
            // Also remove any schedules containing this property
            for (date, schedule) in schedules {
                if schedule.openHomes.contains(where: { $0.property.id == property.id }) {
                    var updatedSchedule = schedule
                    updatedSchedule.openHomes.removeAll { $0.property.id == property.id }
                    if updatedSchedule.openHomes.isEmpty {
                        schedules.removeValue(forKey: date)
                        
                        // Delete empty schedule from Firebase
                        let dateFormatter = ISO8601DateFormatter()
                        let dateString = dateFormatter.string(from: date)
                        db.collection("users").document(userId)
                            .collection("schedules").document(dateString)
                            .delete()
                    } else {
                        schedules[date] = updatedSchedule
                        saveScheduleToFirebase(updatedSchedule, for: date)
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
                if isDark {
                    window.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
                } else {
                    window.backgroundColor = .systemGray6
                }
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
        
        // Load from both local storage and Firebase
        loadProperties()
        loadPropertiesFromFirebase()
        loadSchedulesFromFirebase()
        
        // Listen for auth state changes
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
        }
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
    
    enum SortOption {
        case streetName, suburb, clientName
        
        var title: String {
            switch self {
            case .streetName: return "Street Name"
            case .suburb: return "Suburb"
            case .clientName: return "Client Name"
            }
        }
    }
    
    func getStreetName(_ address: String) -> String {
        let components = address.components(separatedBy: CharacterSet.decimalDigits)
        let streetName = components.joined().trimmingCharacters(in: .whitespaces)
        return streetName
    }
    
    // MARK: - Firebase Methods
    
    func savePropertyToFirebase(_ property: Property) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        print("Saving property to Firebase: \(property.id) with phone: \(property.clientPhone)")
        
        db.collection("users").document(userId)
            .collection("properties").document(property.id.uuidString)
            .setData(property.dictionary) { error in
                if let error = error {
                    print("Error saving property: \(error)")
                } else {
                    print("Successfully saved property to Firebase")
                }
            }
    }
    
    func saveScheduleToFirebase(_ schedule: Schedule, for date: Date) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: date)
        
        print("Saving schedule to Firebase with \(schedule.openHomes.count) open homes")
        
        let scheduleData: [String: Any] = [
            "id": schedule.id.uuidString,
            "date": dateString,
            "isAutoScheduled": schedule.isAutoScheduled,
            "openHomes": schedule.openHomes.map { openHome in
                print("Saving open home with property phone: \(openHome.property.clientPhone)")
                return [
                    "id": openHome.id.uuidString,
                    "property": openHome.property.dictionary,
                    "startTime": dateFormatter.string(from: openHome.startTime),
                    "endTime": dateFormatter.string(from: openHome.endTime),
                    "bufferBeforeStart": dateFormatter.string(from: openHome.bufferBeforeStart),
                    "bufferAfterEnd": dateFormatter.string(from: openHome.bufferAfterEnd)
                ]
            }
        ]
        
        db.collection("users").document(userId)
            .collection("schedules").document(dateString)
            .setData(scheduleData) { error in
                if let error = error {
                    print("Error saving schedule: \(error)")
                } else {
                    print("Successfully saved schedule to Firebase")
                }
            }
    }
    
    func loadPropertiesFromFirebase() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId)
            .collection("properties")
            .addSnapshotListener { querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching properties: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self.properties = documents.compactMap { document -> Property? in
                    let data = document.data()
                    guard let id = data["id"] as? String,
                          let streetAddress = data["streetAddress"] as? String,
                          let suburb = data["suburb"] as? String,
                          let latitude = data["latitude"] as? Double,
                          let longitude = data["longitude"] as? Double else {
                        return nil
                    }
                    
                    let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    let clientFirstName = data["clientFirstName"] as? String ?? ""
                    let clientLastName = data["clientLastName"] as? String ?? ""
                    let clientPhone = data["clientPhone"] as? String ?? ""
                    let openHomeDuration = data["openHomeDuration"] as? Int ?? 30
                    let bufferBefore = data["bufferBefore"] as? Int ?? 5
                    let bufferAfter = data["bufferAfter"] as? Int ?? 5
                    let bedrooms = data["bedrooms"] as? Int ?? 0
                    let bathrooms = data["bathrooms"] as? Int ?? 0
                    let parking = data["parking"] as? Int ?? 0
                    let imageURLString = data["imageURL"] as? String
                    let imageURL = imageURLString.flatMap { URL(string: $0) }
                    
                    return Property(
                        id: UUID(uuidString: id) ?? UUID(),
                        streetAddress: streetAddress,
                        suburb: suburb,
                        coordinates: coordinates,
                        clientFirstName: clientFirstName,
                        clientLastName: clientLastName,
                        clientPhone: clientPhone,
                        openHomeDuration: openHomeDuration,
                        bufferBefore: bufferBefore,
                        bufferAfter: bufferAfter,
                        bedrooms: bedrooms,
                        bathrooms: bathrooms,
                        parking: parking,
                        imageURL: imageURL
                    )
                }
            }
    }
    
    func loadSchedulesFromFirebase() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        print("Loading schedules from Firebase...")
        
        db.collection("users").document(userId)
            .collection("schedules")
            .addSnapshotListener { querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching schedules: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                print("Received \(documents.count) schedule documents")
                let dateFormatter = ISO8601DateFormatter()
                
                self.schedules = documents.reduce(into: [:]) { result, document in
                    let data = document.data()
                    guard let dateString = data["date"] as? String,
                          let date = dateFormatter.date(from: dateString),
                          let openHomesData = data["openHomes"] as? [[String: Any]] else {
                        print("Failed to parse schedule document: \(data)")
                        return
                    }
                    
                    let openHomes = openHomesData.compactMap { openHomeData -> ScheduledOpenHome? in
                        guard let id = openHomeData["id"] as? String,
                              let propertyData = openHomeData["property"] as? [String: Any],
                              let startTimeString = openHomeData["startTime"] as? String,
                              let endTimeString = openHomeData["endTime"] as? String,
                              let bufferBeforeString = openHomeData["bufferBeforeStart"] as? String,
                              let bufferAfterString = openHomeData["bufferAfterEnd"] as? String,
                              let startTime = dateFormatter.date(from: startTimeString),
                              let endTime = dateFormatter.date(from: endTimeString),
                              let bufferBeforeStart = dateFormatter.date(from: bufferBeforeString),
                              let bufferAfterEnd = dateFormatter.date(from: bufferAfterString) else {
                            print("Failed to parse open home data: \(openHomeData)")
                            return nil
                        }
                        
                        // Parse property data
                        guard let property = self.parseProperty(from: propertyData) else {
                            print("Failed to parse property data: \(propertyData)")
                            return nil
                        }
                        
                        print("Loaded open home with property phone: \(property.clientPhone)")
                        
                        return ScheduledOpenHome(
                            id: UUID(uuidString: id) ?? UUID(),
                            property: property,
                            startTime: startTime,
                            endTime: endTime,
                            bufferBeforeStart: bufferBeforeStart,
                            bufferAfterEnd: bufferAfterEnd
                        )
                    }
                    
                    let isAutoScheduled = data["isAutoScheduled"] as? Bool ?? false
                    
                    let schedule = Schedule(
                        id: UUID(uuidString: data["id"] as? String ?? "") ?? UUID(),
                        date: date,
                        openHomes: openHomes,
                        isAutoScheduled: isAutoScheduled
                    )
                    
                    result[date] = schedule
                }
                
                print("Successfully loaded \(self.schedules.count) schedules")
            }
    }
    
    private func parseProperty(from data: [String: Any]) -> Property? {
        guard let id = data["id"] as? String,
              let streetAddress = data["streetAddress"] as? String,
              let suburb = data["suburb"] as? String,
              let latitude = data["latitude"] as? Double,
              let longitude = data["longitude"] as? Double else {
            return nil
        }
        
        let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let clientFirstName = data["clientFirstName"] as? String ?? ""
        let clientLastName = data["clientLastName"] as? String ?? ""
        let clientPhone = data["clientPhone"] as? String ?? ""
        let openHomeDuration = data["openHomeDuration"] as? Int ?? 30
        let bufferBefore = data["bufferBefore"] as? Int ?? 5
        let bufferAfter = data["bufferAfter"] as? Int ?? 5
        let bedrooms = data["bedrooms"] as? Int ?? 0
        let bathrooms = data["bathrooms"] as? Int ?? 0
        let parking = data["parking"] as? Int ?? 0
        let imageURLString = data["imageURL"] as? String
        let imageURL = imageURLString.flatMap { URL(string: $0) }
        
        return Property(
            id: UUID(uuidString: id) ?? UUID(),
            streetAddress: streetAddress,
            suburb: suburb,
            coordinates: coordinates,
            clientFirstName: clientFirstName,
            clientLastName: clientLastName,
            clientPhone: clientPhone,
            openHomeDuration: openHomeDuration,
            bufferBefore: bufferBefore,
            bufferAfter: bufferAfter,
            bedrooms: bedrooms,
            bathrooms: bathrooms,
            parking: parking,
            imageURL: imageURL
        )
    }
    
    // MARK: - User Profile Management
    func uploadProfileImage(_ image: UIImage) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not compress image"])
        }
        
        print("Starting profile image upload for user: \(userId)")
        
        let storageRef = storage.reference()
            .child("profile_images")
            .child("\(userId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            print("Uploading image data...")
            
            // Upload the image and wait for completion
            _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
            
            print("Upload completed, getting download URL...")
            let downloadURL = try await storageRef.downloadURL()
            
            print("Updating user profile with URL: \(downloadURL.absoluteString)")
            try await db.collection("users").document(userId).setData([
                "profileImageURL": downloadURL.absoluteString
            ], merge: true)
            
            // Update local state
            await MainActor.run {
                self.userProfileImage = image
            }
            
            print("Profile image upload completed successfully")
        } catch {
            print("Error uploading profile image: \(error.localizedDescription)")
            throw error
        }
    }
    
    func loadProfileImage() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Cannot load profile image: User not authenticated")
            return
        }
        
        print("Loading profile image for user: \(userId)")
        
        // First try to load from Firebase
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            if let error = error {
                print("Error fetching user document: \(error.localizedDescription)")
                return
            }
            
            if let document = document,
               let imageURLString = document.data()?["profileImageURL"] as? String,
               let imageURL = URL(string: imageURLString) {
                
                print("Found profile image URL: \(imageURLString)")
                
                URLSession.shared.dataTask(with: imageURL) { data, response, error in
                    if let error = error {
                        print("Error downloading image: \(error.localizedDescription)")
                        return
                    }
                    
                    if let data = data, let image = UIImage(data: data) {
                        print("Successfully loaded profile image")
                        DispatchQueue.main.async {
                            self?.userProfileImage = image
                        }
                    } else {
                        print("Could not create image from data")
                    }
                }.resume()
            } else {
                print("No profile image URL found in user document")
            }
        }
    }
    
    func deleteProfileImage() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("Deleting profile image for user: \(userId)")
        
        // Delete from Storage
        let storageRef = storage.reference()
            .child("profile_images")
            .child("\(userId).jpg")
        
        try await storageRef.delete()
        
        // Remove URL from Firestore
        try await db.collection("users").document(userId).updateData([
            "profileImageURL": FieldValue.delete()
        ])
        
        // Update local state
        await MainActor.run {
            self.userProfileImage = nil
        }
        
        print("Profile image deleted successfully")
    }
}

struct ScheduledOpenHome: Identifiable, Codable, Hashable, MapSelectable {
    let id: UUID
    var property: Property
    var startTime: Date
    var endTime: Date
    var bufferBeforeStart: Date
    var bufferAfterEnd: Date
    
    var duration: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }
    
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

// Add dictionary property to Property model
extension Property {
    var dictionary: [String: Any] {
        [
            "id": self.id.uuidString,
            "streetAddress": self.streetAddress,
            "suburb": self.suburb,
            "latitude": self.coordinates.latitude,
            "longitude": self.coordinates.longitude,
            "clientFirstName": self.clientFirstName,
            "clientLastName": self.clientLastName,
            "clientPhone": self.clientPhone,
            "openHomeDuration": self.openHomeDuration,
            "bufferBefore": self.bufferBefore,
            "bufferAfter": self.bufferAfter,
            "bedrooms": self.bedrooms,
            "bathrooms": self.bathrooms,
            "parking": self.parking,
            "imageURL": self.imageURL?.absoluteString as Any
        ]
    }
} 
