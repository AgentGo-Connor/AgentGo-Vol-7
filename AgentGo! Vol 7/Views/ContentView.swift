import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var selectedTab = 0
    @State private var isAuthenticated = false
    @Environment(\.colorScheme) private var colorScheme
    // Store the auth listener handle
    @State private var authListenerHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(Color("f2efeb"))
        navBarAppearance.shadowColor = .clear
        navBarAppearance.shadowImage = UIImage()
        
        // Remove all navigation bar lines
        let navigationBarAppearance = UINavigationBar.appearance()
        navigationBarAppearance.standardAppearance = navBarAppearance
        navigationBarAppearance.compactAppearance = navBarAppearance
        navigationBarAppearance.scrollEdgeAppearance = navBarAppearance
        navigationBarAppearance.setBackgroundImage(UIImage(), for: .default)
        navigationBarAppearance.shadowImage = UIImage()
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(Color("f2efeb"))
        tabBarAppearance.shadowColor = .clear
        tabBarAppearance.shadowImage = UIImage()
        
        // Remove border line
        tabBarAppearance.backgroundEffect = nil
        
        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tabBarAppearance
        tabBar.scrollEdgeAppearance = tabBarAppearance
        tabBar.clipsToBounds = true
        
        // Remove default border
        tabBar.layer.borderWidth = 0
        tabBar.layer.borderColor = UIColor.clear.cgColor
    }
    
    var body: some View {
        Group {
            if isAuthenticated {
                // Main app interface
                TabView(selection: $selectedTab) {
                    MapView()
                        .tabItem {
                            Image(systemName: selectedTab == 0 ? "map.fill" : "map")
                            Text("Map")
                        }
                        .tag(0)
                    
                    PropertiesView()
                        .tabItem {
                            Image(systemName: selectedTab == 1 ? "house.fill" : "house")
                            Text("Properties")
                        }
                        .tag(1)
                    
                    PlannerView()
                        .tabItem {
                            Image(systemName: selectedTab == 2 ? "calendar.badge.clock.fill" : "calendar.badge.clock")
                            Text("Planner")
                        }
                        .tag(2)
                }
                .tint(Color.customAccent)
                .background(colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color(hex: "f2efeb"))
                .toolbarBackground(colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color(hex: "f2efeb"), for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            } else {
                LoginView()
            }
        }
        .environmentObject(viewModel)
        .onAppear {
            // Always reset to MapView on app launch
            selectedTab = 0
             
            // Set up auth state listener and store the handle
            authListenerHandle = Auth.auth().addStateDidChangeListener { _, user in
                withAnimation {
                    isAuthenticated = user != nil
                    if isAuthenticated {
                        selectedTab = 0
                    }
                }
            }
        }
        .onDisappear {
            // Remove the listener when the view disappears
            if let handle = authListenerHandle {
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
} 
