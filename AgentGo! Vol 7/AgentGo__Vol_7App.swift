//
//  AgentGo__Vol_7App.swift
//  AgentGo! Vol 7
//
//  Created by Connor Rorison on 8/12/2024.
//

import SwiftUI
import SwiftUI
import FirebaseCore


class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}
import MapKit
import CoreLocation

@main
struct AgentGo__Vol_7App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var viewModel = AppViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(viewModel.isDarkMode ? .dark : .light)
                .tint(.customAccent)
        }
    }
}
