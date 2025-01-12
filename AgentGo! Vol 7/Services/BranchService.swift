import BranchSDK
import FirebaseDynamicLinks

enum BranchError: Error {
    case initializationError
    case linkGenerationError(String)
    case timeout
}

enum BranchLinkAction {
    case teamInvite(inviteId: String, teamId: String)
}

class BranchService {
    static let shared = BranchService()
    
    private init() {
        print("BranchService: Initializing...")
        // Initialize Branch
        let branch = Branch.getInstance()
        branch.initSession()
        
        // Enable Branch logging for debugging
        #if DEBUG
        Branch.enableLogging()
        print("BranchService: Debug logging enabled")
        #endif
    }
    
    func createTeamInviteLink(inviteId: String, teamId: String) async throws -> URL {
        print("BranchService: Creating team invite link...")
        
        // Create the deep link URL with invite parameters
        var components = URLComponents()
        components.scheme = "https"
        components.host = "agentgo.au"
        components.path = "/invite"
        components.queryItems = [
            URLQueryItem(name: "inviteId", value: inviteId),
            URLQueryItem(name: "teamId", value: teamId),
            URLQueryItem(name: "link", value: "https://agentgo.au/invite")
        ]
        
        guard let linkUrl = components.url else {
            throw URLError(.badURL)
        }
        
        let linkBuilder = DynamicLinkComponents(
            link: linkUrl,
            domainURIPrefix: "https://agentgo.page.link"
        )
        
        // Configure iOS parameters
        linkBuilder?.iOSParameters = DynamicLinkIOSParameters(bundleID: "au.com.agentgo.app")
        linkBuilder?.iOSParameters?.appStoreID = "6740009453"
        
        // Configure Android parameters (if you have an Android app)
        linkBuilder?.androidParameters = DynamicLinkAndroidParameters(packageName: "com.agentgo.app")
        
        // Configure the social media metadata
        let socialMetaTagParameters = DynamicLinkSocialMetaTagParameters()
        socialMetaTagParameters.title = "Join My AgentGo Team"
        socialMetaTagParameters.descriptionText = "You've been invited to join a team on AgentGo"
        linkBuilder?.socialMetaTagParameters = socialMetaTagParameters
        
        // Set link behavior for iOS
        linkBuilder?.navigationInfoParameters = DynamicLinkNavigationInfoParameters()
        linkBuilder?.navigationInfoParameters?.isForcedRedirectEnabled = true
        
        // Create the short dynamic link
        return try await withCheckedThrowingContinuation { continuation in
            guard (linkBuilder?.url) != nil else {
                continuation.resume(throwing: URLError(.badURL))
                return
            }
            
            let options = DynamicLinkComponentsOptions()
            options.pathLength = .short
            
            linkBuilder?.shorten { shortURL, warnings, error in
                if let error = error {
                    print("Error creating dynamic link: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                
                if let shortURL = shortURL {
                    print("Successfully created dynamic link: \(shortURL)")
                    continuation.resume(returning: shortURL)
                } else {
                    print("No URL and no error returned")
                    continuation.resume(throwing: BranchError.linkGenerationError("No URL generated"))
                }
            }
        }
    }
    
    func handleDeepLink(_ params: [AnyHashable: Any]) -> BranchLinkAction? {
        // Log deep link received
        print("BranchService: Handling deep link with params: \(params)")
        let event = BranchEvent.init(name: "VIEW_ITEM")
        let stringParams = params.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String {
                result[key] = String(describing: pair.value)
            }
        }
        event.customData = stringParams
        event.logEvent()
        
        guard let isClicked = params["+clicked_branch_link"] as? Bool,
              isClicked == true,
              let inviteId = params["inviteId"] as? String,
              let teamId = params["teamId"] as? String else {
            print("BranchService: Invalid deep link params")
            return nil
        }
        
        // Track successful deep link processing
        print("BranchService: Processing team invite deep link")
        let inviteEvent = BranchEvent.init(name: "team_invite_opened")
        inviteEvent.customData = ["inviteId": inviteId, "teamId": teamId]
        inviteEvent.logEvent()
        
        return .teamInvite(inviteId: inviteId, teamId: teamId)
    }
    
    // Track user events
    func trackUserSignedUp(method: String) {
        let event = BranchEvent.init(name: "user_signed_up")
        event.customData = ["method": method]
        event.logEvent()
    }
    
    func trackTeamCreated(teamId: String) {
        let event = BranchEvent.init(name: "team_created")
        event.customData = ["teamId": teamId]
        event.logEvent()
    }
    
    func trackTeamJoined(teamId: String) {
        let event = BranchEvent.init(name: "team_joined")
        event.customData = ["teamId": teamId]
        event.logEvent()
    }
    
    func setUserIdentity(_ userId: String) {
        Branch.getInstance().setIdentity(userId)
    }
    
    func clearUserIdentity() {
        Branch.getInstance().logout()
    }
} 
