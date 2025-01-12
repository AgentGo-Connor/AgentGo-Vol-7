import FirebaseDynamicLinks

class DynamicLinkManager {
    static let shared = DynamicLinkManager()
    
    private init() {}
    
    func createTeamInviteLink(inviteId: String, teamId: String) async throws -> URL {
        // Create the deep link URL with invite parameters
        var components = URLComponents()
        components.scheme = "https"
        components.host = "agentgo.app"
        components.path = "/invite"
        components.queryItems = [
            URLQueryItem(name: "inviteId", value: inviteId),
            URLQueryItem(name: "teamId", value: teamId)
        ]
        
        guard let linkUrl = components.url else {
            throw URLError(.badURL)
        }
        
        let linkBuilder = DynamicLinkComponents(
            link: linkUrl,
            domainURIPrefix: "https://agentgo.page.link"
        )
        
        // Configure iOS parameters
        linkBuilder?.iOSParameters = DynamicLinkIOSParameters(bundleID: "com.agentgo.app")
        linkBuilder?.iOSParameters?.appStoreID = "6740009453" // Updated with your App Store ID
        
        // Configure Android parameters (if you have an Android app)
        linkBuilder?.androidParameters = DynamicLinkAndroidParameters(packageName: "com.agentgo.app")
        
        // Configure the social media metadata
        let socialMetaTagParameters = DynamicLinkSocialMetaTagParameters()
        socialMetaTagParameters.title = "Join My AgentGo Team"
        socialMetaTagParameters.descriptionText = "You've been invited to join a team on AgentGo"
        // socialMetaTagParameters.imageURL = URL(string: "YOUR_IMAGE_URL") // Optional: Add a preview image
        linkBuilder?.socialMetaTagParameters = socialMetaTagParameters
        
        // Set link behavior for iOS
        linkBuilder?.navigationInfoParameters = DynamicLinkNavigationInfoParameters()
        linkBuilder?.navigationInfoParameters?.isForcedRedirectEnabled = true
        
        // Create the short dynamic link
        return try await withCheckedThrowingContinuation { continuation in
            guard let longDynamicLink = linkBuilder?.url else {
                continuation.resume(throwing: URLError(.badURL))
                return
            }
            
            let options = DynamicLinkComponentsOptions()
            options.pathLength = .short
            
            DynamicLinkComponents.shortenURL(longDynamicLink, options: options) { shortURL, warnings, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let shortURL = shortURL {
                    continuation.resume(returning: shortURL)
                } else {
                    continuation.resume(throwing: URLError(.badURL))
                }
            }
        }
    }
} 