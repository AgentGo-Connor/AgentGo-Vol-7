import Foundation
import FirebaseAuth
import UIKit
import FirebaseAnalytics

enum AuthError: LocalizedError, Hashable {
    case invalidCredential
    case networkError
    case tooManyAttempts
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case userDisabled
    case operationNotAllowed
    case differentCredential(email: String)
    case accountLocked(duration: TimeInterval)
    case invalidVerificationCode
    case expiredActionCode
    case invalidActionCode
    case missingEmail
    case missingPassword
    case passwordMismatch
    case credentialAlreadyInUse
    case unknown(message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid credentials. Please check your email and password."
        case .networkError:
            return "Network error. Please check your internet connection and try again."
        case .tooManyAttempts:
            return "Too many sign-in attempts. Please try again later or reset your password."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password should be at least 6 characters long."
        case .emailAlreadyInUse:
            return "An account already exists with this email address."
        case .userDisabled:
            return "This account has been disabled. Please contact support."
        case .operationNotAllowed:
            return "This sign-in method is not allowed. Please try another method."
        case .differentCredential(let email):
            return "An account already exists with \(email). Please sign in using your original sign-in method."
        case .accountLocked(let duration):
            let minutes = Int(ceil(duration / 60))
            return "Account temporarily locked. Please try again in \(minutes) minute\(minutes == 1 ? "" : "s")."
        case .invalidVerificationCode:
            return "Invalid verification code. Please try again."
        case .expiredActionCode:
            return "This link has expired. Please request a new one."
        case .invalidActionCode:
            return "Invalid verification link. Please request a new one."
        case .missingEmail:
            return "Please enter your email address."
        case .missingPassword:
            return "Please enter your password."
        case .passwordMismatch:
            return "Passwords do not match."
        case .credentialAlreadyInUse:
            return "This account is already linked to another user."
        case .unknown(let message):
            return message
        }
    }
    
    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        switch self {
        case .invalidCredential:
            hasher.combine(0)
        case .networkError:
            hasher.combine(1)
        case .tooManyAttempts:
            hasher.combine(2)
        case .invalidEmail:
            hasher.combine(3)
        case .weakPassword:
            hasher.combine(4)
        case .emailAlreadyInUse:
            hasher.combine(5)
        case .userDisabled:
            hasher.combine(6)
        case .operationNotAllowed:
            hasher.combine(7)
        case .differentCredential(let email):
            hasher.combine(8)
            hasher.combine(email)
        case .accountLocked(let duration):
            hasher.combine(10)
            hasher.combine(duration)
        case .invalidVerificationCode:
            hasher.combine(11)
        case .expiredActionCode:
            hasher.combine(12)
        case .invalidActionCode:
            hasher.combine(13)
        case .missingEmail:
            hasher.combine(14)
        case .missingPassword:
            hasher.combine(15)
        case .passwordMismatch:
            hasher.combine(16)
        case .credentialAlreadyInUse:
            hasher.combine(17)
        case .unknown(let message):
            hasher.combine(9)
            hasher.combine(message)
        }
    }
    
    // Implement Equatable (required by Hashable)
    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidCredential, .invalidCredential),
             (.networkError, .networkError),
             (.tooManyAttempts, .tooManyAttempts),
             (.invalidEmail, .invalidEmail),
             (.weakPassword, .weakPassword),
             (.emailAlreadyInUse, .emailAlreadyInUse),
             (.userDisabled, .userDisabled),
             (.operationNotAllowed, .operationNotAllowed):
            return true
        case (.differentCredential(let email1), .differentCredential(let email2)):
            return email1 == email2
        case (.accountLocked(let duration1), .accountLocked(let duration2)):
            return duration1 == duration2
        case (.invalidVerificationCode, .invalidVerificationCode),
             (.expiredActionCode, .expiredActionCode),
             (.invalidActionCode, .invalidActionCode),
             (.missingEmail, .missingEmail),
             (.missingPassword, .missingPassword),
             (.passwordMismatch, .passwordMismatch),
             (.credentialAlreadyInUse, .credentialAlreadyInUse):
            return true
        case (.unknown(let message1), .unknown(let message2)):
            return message1 == message2
        default:
            return false
        }
    }
}

class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    private let haptics = UINotificationFeedbackGenerator()
    
    // Rate limiting properties
    private var signInAttempts: [String: [Date]] = [:] // email: [attempt timestamps]
    private let maxAttempts = 5
    private let lockoutDuration: TimeInterval = 300 // 5 minutes
    private let attemptWindow: TimeInterval = 600 // 10 minutes
    
    // Analytics properties
    private var errorCounts: [AuthError: Int] = [:]
    private let analyticsQueue = DispatchQueue(label: "com.agentgo.analytics")
    
    private init() {
        // Start cleanup timer for rate limiting
        Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.cleanupOldAttempts()
        }
    }
    
    func handleError(_ error: Error) -> AuthError {
        haptics.notificationOccurred(.error)
        
        let authError: AuthError
        
        if let nsError = error as NSError? {
            switch nsError.code {
            case AuthErrorCode.networkError.rawValue:
                authError = .networkError
            case AuthErrorCode.tooManyRequests.rawValue:
                authError = .tooManyAttempts
            case AuthErrorCode.invalidEmail.rawValue:
                authError = .invalidEmail
            case AuthErrorCode.weakPassword.rawValue:
                authError = .weakPassword
            case AuthErrorCode.emailAlreadyInUse.rawValue:
                authError = .emailAlreadyInUse
            case AuthErrorCode.userDisabled.rawValue:
                authError = .userDisabled
            case AuthErrorCode.operationNotAllowed.rawValue:
                authError = .operationNotAllowed
            case AuthErrorCode.accountExistsWithDifferentCredential.rawValue:
                if let email = (error as NSError).userInfo[AuthErrorUserInfoEmailKey] as? String {
                    authError = .differentCredential(email: email)
                } else {
                    authError = .unknown(message: error.localizedDescription)
                }
            case AuthErrorCode.invalidVerificationCode.rawValue:
                authError = .invalidVerificationCode
            case AuthErrorCode.expiredActionCode.rawValue:
                authError = .expiredActionCode
            case AuthErrorCode.invalidActionCode.rawValue:
                authError = .invalidActionCode
            case AuthErrorCode.credentialAlreadyInUse.rawValue:
                authError = .credentialAlreadyInUse
            default:
                authError = .unknown(message: error.localizedDescription)
            }
        } else {
            authError = .unknown(message: error.localizedDescription)
        }
        
        trackError(authError)
        return authError
    }
    
    // Rate limiting functions
    func checkRateLimit(for email: String) throws {
        let now = Date()
        let attempts = signInAttempts[email, default: []]
        
        // Clean up old attempts
        let recentAttempts = attempts.filter { now.timeIntervalSince($0) < attemptWindow }
        
        if recentAttempts.count >= maxAttempts {
            if let oldestAttempt = recentAttempts.first {
                let lockoutEnd = oldestAttempt.addingTimeInterval(lockoutDuration)
                if now < lockoutEnd {
                    let remainingTime = lockoutEnd.timeIntervalSince(now)
                    throw AuthError.accountLocked(duration: remainingTime)
                }
            }
        }
        
        // Record new attempt
        signInAttempts[email] = (recentAttempts + [now])
    }
    
    private func cleanupOldAttempts() {
        let now = Date()
        for (email, attempts) in signInAttempts {
            let recentAttempts = attempts.filter { now.timeIntervalSince($0) < attemptWindow }
            if recentAttempts.isEmpty {
                signInAttempts.removeValue(forKey: email)
            } else {
                signInAttempts[email] = recentAttempts
            }
        }
    }
    
    private func trackError(_ error: AuthError) {
        analyticsQueue.async {
            self.errorCounts[error, default: 0] += 1
            
            // Log to Firebase Analytics
            var params: [String: Any] = [
                "error_type": String(describing: error),
                "error_count": self.errorCounts[error] ?? 1
            ]
            
            if case .differentCredential(let email) = error {
                params["affected_email"] = email
            }
            
            Analytics.logEvent("auth_error", parameters: params)
            
            #if DEBUG
            print("Authentication Error: \(error), Count: \(self.errorCounts[error] ?? 1)")
            #endif
        }
    }
    
    func resetErrorCounts() {
        analyticsQueue.async {
            self.errorCounts.removeAll()
        }
    }
    
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            Analytics.logEvent("user_logout", parameters: nil)
        } catch {
            haptics.notificationOccurred(.error)
            throw error
        }
    }
} 