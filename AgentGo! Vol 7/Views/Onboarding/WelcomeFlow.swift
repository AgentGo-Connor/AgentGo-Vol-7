import SwiftUI
import FirebaseAuth
import FirebaseAnalytics

struct WelcomeFlow: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WelcomeFlowViewModel()
    @State private var currentStep = 0
    
    var body: some View {
        NavigationStack {
            TabView(selection: $currentStep) {
                // Step 1: Welcome
                WelcomeStepView(
                    title: "Welcome to AgentGo!",
                    subtitle: "Let's set up your agent profile in just a few steps",
                    buttonTitle: "Get Started"
                ) {
                    withAnimation { currentStep = 1 }
                }
                .tag(0)
                
                // Step 2: Agent Details
                AgentDetailsStep(viewModel: viewModel, currentStep: $currentStep)
                    .tag(1)
                
                // Step 3: Agency Details
                AgencyDetailsStep(viewModel: viewModel, currentStep: $currentStep)
                    .tag(2)
                
                // Step 4: Preferences
                PreferencesStep(viewModel: viewModel) {
                    // Complete onboarding
                    Task {
                        await viewModel.completeOnboarding()
                        dismiss()
                    }
                }
                .tag(3)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if currentStep < 3 {
                        Button("Skip") {
                            Task {
                                await viewModel.completeOnboarding()
                                dismiss()
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// Individual step views
struct WelcomeStepView: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "house.fill")
                .font(.system(size: 80))
                .foregroundStyle(.customAccent)
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: action) {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.customAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// ViewModel
class WelcomeFlowViewModel: ObservableObject {
    @Published var agentName = ""
    @Published var phoneNumber = ""
    @Published var licenseNumber = ""
    @Published var agencyName = ""
    @Published var agencyAddress = ""
    @Published var defaultOpenHomeDuration = 30
    @Published var defaultBufferTime = 15
    
    func completeOnboarding() async {
        guard let user = Auth.auth().currentUser else { return }
        
        // Create agent profile
        let agent = Agent(
            id: user.uid,
            name: agentName.isEmpty ? (user.displayName ?? "User") : agentName,
            email: user.email ?? "",
            phoneNumber: phoneNumber,
            licenseNumber: licenseNumber,
            agencyName: agencyName,
            agencyAddress: agencyAddress,
            photoURL: user.photoURL?.absoluteString
        )
        
        do {
            try await RealEstateService.shared.createAgent(agent)
            
            // Save preferences
            UserDefaults.standard.set(defaultOpenHomeDuration, forKey: "defaultOpenHomeDuration")
            UserDefaults.standard.set(defaultBufferTime, forKey: "defaultBufferTime")
            
            // Mark onboarding as complete
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            
            // Log analytics
            Analytics.logEvent("onboarding_complete", parameters: [
                "has_phone": !phoneNumber.isEmpty,
                "has_license": !licenseNumber.isEmpty,
                "has_agency": !agencyName.isEmpty
            ])
        } catch {
            print("Error creating agent profile: \(error)")
        }
    }
} 