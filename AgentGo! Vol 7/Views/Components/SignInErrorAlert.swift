import SwiftUI

struct SignInErrorAlert: View {
    let message: String
    let isNoAccount: Bool
    let onDismiss: () -> Void
    let onSignUp: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text(message)
                .multilineTextAlignment(.center)
            
            if isNoAccount {
                Button(action: {
                    onDismiss()
                    onSignUp()
                }) {
                    Text("Sign Up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.customAccent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            Button(action: onDismiss) {
                Text(isNoAccount ? "Cancel" : "OK")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }
} 