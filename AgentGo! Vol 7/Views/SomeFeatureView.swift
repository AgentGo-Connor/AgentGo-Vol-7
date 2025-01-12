import SwiftUI

struct SomeFeatureView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false
    
    var body: some View {
        Button("Use Pro Feature") {
            if subscriptionManager.isPro {
                // Use the pro feature
            } else {
                showingPaywall = true
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
} 