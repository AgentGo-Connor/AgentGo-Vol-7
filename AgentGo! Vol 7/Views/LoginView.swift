import SwiftUI
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import UIKit

struct LoginView: View {
    @AppStorage("savedEmail") private var savedEmail = ""
    @AppStorage("rememberMe") private var rememberMe = false
    @State private var email = ""
    @State private var password = ""
    @State private var isShowingSignUp = false
    @State private var isShowingForgotPassword = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var currentNonce: String?
    @State private var showingCustomAlert = false
    @State private var isNoAccountError = false
    @State private var showingWelcomeFlow = false
    @State private var isAnimating = false
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToMain = false
    @Environment(\.colorScheme) private var colorScheme
    private enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(uiColor: .systemBackground) : Color(hex: "f2efeb"))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Logo/Title Area
                        VStack(spacing: 12) {
                            if let iconImage = UIImage(named: "AppIcon") ?? Bundle.main.icon {
                                Image(uiImage: iconImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .padding(.bottom, 8)
                            }
                            
                            Text("AgentGo!")
                                .font(.title2.bold())
                            
                            Text("Your Open Home Assistant")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                        
                        // Login Form
                        VStack(spacing: 12) {
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .password
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onAppear {
                                    if rememberMe {
                                        email = savedEmail
                                    }
                                }
                            
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit {
                                    if !email.isEmpty && !password.isEmpty {
                                        login()
                                    }
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            HStack {
                                // Remember Me section
                                HStack(spacing: 8) {
                                    Text("Remember Me")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Toggle("", isOn: $rememberMe)
                                        .tint(.customAccent)
                                        .labelsHidden()
                                }
                                
                                Spacer()
                                
                                // Forgot Password Button
                                Button("Forgot Password?") {
                                    isShowingForgotPassword = true
                                }
                                .font(.subheadline)
                                .foregroundStyle(Color.customAccent)
                            }
                            .padding(.top, 4)
                        }
                        .padding(.horizontal)
                        
                        // Main Login Button
                        Button(action: {
                            login()
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.customAccent)
                                    .frame(height: 50)
                                
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Login")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(email.isEmpty || password.isEmpty || isLoading)
                        .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1)
                        .padding(.horizontal)
                        
                        // Divider with improved spacing
                        HStack {
                            Rectangle()
                                .fill(Color(.systemGray4))
                                .frame(height: 1)
                            
                            Text("or")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            
                            Rectangle()
                                .fill(Color(.systemGray4))
                                .frame(height: 1)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        // Social Sign In Options
                        VStack(spacing: 12) {
                            // Sign in with Apple
                            SignInWithAppleButton { request in
                                let nonce = randomNonceString()
                                currentNonce = nonce
                                request.requestedScopes = [.email]
                                request.nonce = sha256(nonce)
                            } onCompletion: { result in
                                switch result {
                                case .success(let authResults):
                                    guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else {
                                        return
                                    }
                                    
                                    guard let nonce = currentNonce else {
                                        alertMessage = "Invalid state: A login callback was received, but no login request was sent."
                                        showingCustomAlert = true
                                        return
                                    }
                                    
                                    guard let appleIDToken = appleIDCredential.identityToken else {
                                        alertMessage = "Unable to fetch identity token"
                                        showingCustomAlert = true
                                        return
                                    }
                                    
                                    guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                                        alertMessage = "Unable to serialize token string from data"
                                        showingCustomAlert = true
                                        return
                                    }
                                    
                                    let firebaseCredential = OAuthProvider.credential(
                                        providerID: AuthProviderID.apple,
                                        idToken: idTokenString,
                                        rawNonce: nonce,
                                        accessToken: nil
                                    )
                                    
                                    Auth.auth().signIn(with: firebaseCredential) { result, error in
                                        if let error = error {
                                            alertMessage = error.localizedDescription
                                            showingCustomAlert = true
                                            return
                                        }
                                        
                                        // Log successful login
                                        Task {
                                            await AnalyticsService.shared.logEvent("user_login", parameters: [
                                                "method": "apple"
                                            ])
                                            // Track sign in with Branch
                                            BranchService.shared.trackUserSignedUp(method: "apple")
                                            if let userId = result?.user.uid {
                                                BranchService.shared.setUserIdentity(userId)
                                            }
                                        }
                                        
                                        // Dismiss login view
                                        dismiss()
                                    }
                                    
                                case .failure(let error):
                                    alertMessage = error.localizedDescription
                                    showingCustomAlert = true
                                }
                            }
                            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .padding(.horizontal)
                            
                            // Sign in with Google
                            Button {
                                signInWithGoogle()
                            } label: {
                                HStack(spacing: 8) {
                                    Image("google_logo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                    
                                    Text("Sign in with Google")
                                        .font(.body.bold())
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.horizontal)
                        
                        // Sign Up Link
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundStyle(.secondary)
                            
                            Button("Sign Up") {
                                isShowingSignUp = true
                            }
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.customAccent)
                        }
                        .font(.subheadline)
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .foregroundColor(.customAccent)
                }
            }
            .alert("Error", isPresented: $showingCustomAlert) {
                if isNoAccountError {
                    Button("Create Account") {
                        isShowingSignUp = true
                    }
                    Button("Try Again", role: .cancel) {}
                } else {
                    Button("OK", role: .cancel) {}
                }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $isShowingSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $isShowingForgotPassword) {
                ForgotPasswordView()
            }
        }
    }
    
    private func login() {
        isAnimating = true
        isLoading = true
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoading = false
            isAnimating = false
            
            if let error = error {
                switch (error as NSError).code {
                case AuthErrorCode.wrongPassword.rawValue:
                    alertMessage = "Incorrect password. Please try again."
                case AuthErrorCode.invalidEmail.rawValue:
                    alertMessage = "Invalid email format."
                case AuthErrorCode.userNotFound.rawValue:
                    alertMessage = "No account found with this email."
                    isNoAccountError = true
                case AuthErrorCode.userDisabled.rawValue:
                    alertMessage = "This account has been disabled."
                case AuthErrorCode.tooManyRequests.rawValue:
                    alertMessage = "Too many attempts. Please try again later."
                default:
                    alertMessage = "An error occurred. Please try again."
                }
                showingCustomAlert = true
            } else {
                // Save email if remember me is enabled
                if rememberMe {
                    savedEmail = email
                } else {
                    savedEmail = ""
                }
                
                // Log successful login
                Task {
                    await AnalyticsService.shared.logEvent("user_login", parameters: [
                        "method": "email"
                    ])
                }
                
                // Dismiss login view
                dismiss()
            }
        }
    }
    
    private func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                alertMessage = error.localizedDescription
                showingCustomAlert = true
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            Auth.auth().signIn(with: credential) { result, error in
                if let error = error {
                    alertMessage = error.localizedDescription
                    showingCustomAlert = true
                    return
                }
                
                // Log successful login
                Task {
                    await AnalyticsService.shared.logEvent("user_login", parameters: [
                        "method": "google"
                    ])
                    // Track sign in with Branch
                    BranchService.shared.trackUserSignedUp(method: "google")
                    if let userId = result?.user.uid {
                        BranchService.shared.setUserIdentity(userId)
                    }
                }
                
                // Dismiss login view
                dismiss()
            }
        }
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

extension Bundle {
    var icon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}

#Preview {
    if FirebaseApp.app() == nil {
        FirebaseApp.configure()
    }
    return LoginView()
} 