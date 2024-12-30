//
//  ContentView.swift
//  AgentGo! Vol 7
//
//  Created by Connor Rorison on 8/12/2024.
//

import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(0)
            
            PropertiesView()
                .tabItem {
                    Label("Properties", systemImage: "house")
                }
                .tag(1)
            
            PlannerView()
                .tabItem {
                    Label("Planner", systemImage: "calendar")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .tint(Color.customAccent)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
