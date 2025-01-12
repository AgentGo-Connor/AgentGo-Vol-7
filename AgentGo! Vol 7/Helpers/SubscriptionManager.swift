import Foundation
import RevenueCat

class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    @Published var isPro = false
    
    private init() {
        checkSubscriptionStatus()
    }
    
    func checkSubscriptionStatus() {
        Task {
            do {
                let customerInfo = try await Purchases.shared.customerInfo()
                await MainActor.run {
                    isPro = customerInfo.entitlements["pro"]?.isActive == true
                }
            } catch {
                print("Failed to check subscription status: \(error)")
            }
        }
    }
} 