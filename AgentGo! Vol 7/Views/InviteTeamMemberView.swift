import SwiftUI

struct InviteTeamMemberView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss: DismissAction
    @State private var viewState = ViewState()
    @State private var showError = false
    @State private var errorMessage = ""
    
    struct ViewState {
        var inviteEmail = ""
        var isLoading = false
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $viewState.inviteEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disabled(viewState.isLoading)
                }
                
                Section {
                    Button(action: sendInvite) {
                        if viewState.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Send Invite")
                        }
                    }
                    .disabled(viewState.inviteEmail.isEmpty || viewState.isLoading)
                }
            }
            .navigationTitle("Invite Team Member")
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func sendInvite() {
        print("Starting sendInvite...")
        guard !viewState.isLoading else { return }
        
        viewState.isLoading = true
        print("Generating invite link...")
        
        Task {
            do {
                let inviteLink = try await viewModel.teamManager.generateInviteLink(for: viewState.inviteEmail)
                print("Successfully generated invite link: \(inviteLink)")
                viewState.isLoading = false
                dismiss()
            } catch {
                print("Error generating invite link: \(error)")
                viewState.isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
} 