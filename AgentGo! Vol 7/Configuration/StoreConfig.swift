import Foundation
import RevenueCat

enum StoreConfig {
    static let apiKey = "sk_BUuITrGKIfkGOJYSXzXmxvgzvvrrc"
    
    static func configure() {
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: apiKey)
                .with(storeKitVersion: .storeKit2)
                .build()
        )
        
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
    }
} 
