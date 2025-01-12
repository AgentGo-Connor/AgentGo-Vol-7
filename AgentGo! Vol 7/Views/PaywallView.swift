import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PaywallViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.customAccent)
                        
                        Text("AgentGo! Pro")
                            .font(.title.bold())
                        
                        Text("Unlock all features and maximize your open home efficiency")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Features List
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "calendar.badge.clock", title: "Auto Scheduling", description: "Optimize your open home schedule automatically")
                        FeatureRow(icon: "map", title: "Route Planning", description: "Get the most efficient route between properties")
                        FeatureRow(icon: "bell.badge", title: "Smart Notifications", description: "Automatic reminders for vendors and open homes")
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Analytics", description: "Track your open home performance")
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    
                    // Subscription Options
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        ForEach(viewModel.packages) { package in
                            PackageButton(package: package) {
                                Task {
                                    await viewModel.purchase(package)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Purchase Failed", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.customAccent)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PackageButton: View {
    let package: Package
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(package.storeProduct.localizedTitle)
                    .font(.headline)
                Text(package.storeProduct.localizedPriceString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.customAccent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }
}

class PaywallViewModel: ObservableObject {
    @Published var packages: [Package] = []
    @Published var isLoading = true
    @Published var showError = false
    @Published var errorMessage = ""
    
    init() {
        Task {
            await loadPackages()
        }
    }
    
    @MainActor
    func loadPackages() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            if let current = offerings.current {
                packages = current.availablePackages
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    @MainActor
    func purchase(_ package: Package) async {
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.customerInfo.entitlements["pro"]?.isActive == true {
                // Handle successful purchase
                UserDefaults.standard.set(true, forKey: "isPro")
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
} 