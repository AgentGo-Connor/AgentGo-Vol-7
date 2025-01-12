import SwiftUI
import FirebaseCore
import BranchSDK
import FirebaseAppCheck
import Network

class AppDelegate: NSObject, UIApplicationDelegate {
    private var networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = false
    private var initializationComplete = false
    
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Ensure initialization happens only once
        guard !initializationComplete else { return true }
        
        // Start network monitoring first
        startNetworkMonitoring()
        
        // Configure Firebase and App Check with proper error handling
        configureFirebase()
        
        // Configure Branch with proper error handling and validation
        configureBranchSafely(with: launchOptions)
        
        initializationComplete = true
        return true
    }
    
    private func configureFirebase() {
        do {
            // Enable Firebase debug logging in debug builds
            #if DEBUG
            FirebaseConfiguration.shared.setLoggerLevel(.debug)
            #endif
            
            // Configure Firebase first if not already configured
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
            }
            
            // Then configure App Check if not already configured
            if AppCheck.appCheck().provider == nil {
                let providerFactory = AppCheckDebugProviderFactory()
                AppCheck.setAppCheckProviderFactory(providerFactory)
            }
            
            print("Firebase and AppCheck configured successfully")
        } catch {
            print("Error configuring Firebase/AppCheck: \(error)")
            // Post notification for error handling
            NotificationCenter.default.post(
                name: .init("FirebaseConfigError"),
                object: nil,
                userInfo: ["error": error]
            )
        }
    }
    
    private func configureBranchSafely(with launchOptions: [UIApplication.LaunchOptionsKey : Any]?) {
        // Ensure we're on main thread for UI updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let key: String
                #if DEBUG
                Branch.setUseTestBranchKey(true)
                Branch.enableLogging()
                key = "key_test_jFpXq421taIKqmzigZOG6hfauCpR5f7G"
                #else
                Branch.setUseTestBranchKey(false)
                key = "key_live_jFpXq421taIKqmzigZOG6hfauCpR5f7G"
                #endif
                
                // Validate key
                guard !key.isEmpty else {
                    throw NSError(domain: "BranchSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Branch key"])
                }
                
                // Configure Branch with retry mechanism
                self.configureBranchWithRetry(key: key, attempts: 3, launchOptions: launchOptions)
            } catch {
                print("Error configuring Branch: \(error.localizedDescription)")
                NotificationCenter.default.post(
                    name: .branchInitError,
                    object: nil,
                    userInfo: ["error": error]
                )
            }
        }
    }
    
    private func configureBranchWithRetry(key: String, attempts: Int, launchOptions: [UIApplication.LaunchOptionsKey : Any]?) {
        guard attempts > 0 else {
            print("Branch initialization failed after all retry attempts")
            return
        }
        
        Branch.setBranchKey(key)
        
        // Configure Branch with safe defaults
        let branch = Branch.getInstance()
        branch.setRetryInterval(1.0)
        branch.setNetworkTimeout(10.0)
        
        // Initialize session with error handling and retry
        branch.initSession(launchOptions: launchOptions) { [weak self] params, error in
            if let error = error {
                print("Branch initialization error (attempts left: \(attempts - 1)): \(error.localizedDescription)")
                
                // Retry after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self?.configureBranchWithRetry(key: key, attempts: attempts - 1, launchOptions: launchOptions)
                }
                return
            }
            
            print("Branch initialized successfully")
            NotificationCenter.default.post(name: .branchInitSuccess, object: nil)
            
            if let params = params {
                self?.handleBranchDeepLink(params)
            }
        }
    }
    
    // Required for Firebase swizzling
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    }
    
    func application(_ application: UIApplication,
                    didFailToRegisterForRemoteNotificationsWithError error: Error) {
    }
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = path.status == .satisfied
                print("Network status changed: \(path.status == .satisfied ? "Connected" : "Disconnected")")
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
        networkMonitor.start(queue: queue)
    }
    
    // Handle universal links
    func application(_ application: UIApplication, 
                    continue userActivity: NSUserActivity,
                    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Let Branch handle the deep link
        Branch.getInstance().continue(userActivity)
        return true
    }
    
    // Handle custom scheme URLs
    func application(_ app: UIApplication,
                    open url: URL,
                    options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Let Branch handle the URL
        Branch.getInstance().application(app, open: url, options: options)
        return true
    }
    
    private func handleBranchDeepLink(_ params: [AnyHashable: Any]) {
        if let action = BranchService.shared.handleDeepLink(params) {
            switch action {
            case .teamInvite(let inviteId, let teamId):
                NotificationCenter.default.post(
                    name: .teamInviteReceived,
                    object: nil,
                    userInfo: ["inviteId": inviteId, "teamId": teamId]
                )
            }
        }
    }
}

// Add extension for the notification name
extension Notification.Name {
    static let teamInviteReceived = Notification.Name("teamInviteReceived")
    static let branchInitSuccess = Notification.Name("branchInitSuccess")
    static let branchInitError = Notification.Name("branchInitError")
}

@main
struct AgentGoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var viewModel = AppViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onReceive(NotificationCenter.default.publisher(for: .teamInviteReceived)) { notification in
                    handleTeamInvite(notification)
                }
        }
    }
    
    private func handleTeamInvite(_ notification: Notification) {
        guard let inviteId = notification.userInfo?["inviteId"] as? String,
              let teamId = notification.userInfo?["teamId"] as? String else { return }
        
        Task {
            do {
                try await viewModel.teamManager.acceptInvite(inviteId: inviteId)
                // Track successful team join
                BranchService.shared.trackTeamJoined(teamId: teamId)
            } catch {
                print("Error accepting invite: \(error.localizedDescription)")
            }
        }
    }
} 