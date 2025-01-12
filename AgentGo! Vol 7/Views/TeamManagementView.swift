import SwiftUI

struct TeamManagementView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @StateObject private var viewState = TeamManagementViewState()
    
    var body: some View {
        List {
            if let team = viewModel.teamManager.currentTeam {
                // Team Info Section
                Section("Team Info") {
                    VStack(alignment: .leading) {
                        Text(team.name)
                            .font(.headline)
                        Text("Created \(team.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Team Members Section
                Section("Team Members") {
                    ForEach(viewModel.teamManager.teamMembers) { member in
                        TeamMemberRow(member: member)
                    }
                }
                
                // Invite Section
                Section {
                    Button {
                        viewState.activeSheet = .invite
                    } label: {
                        Label("Invite Team Member", systemImage: "person.badge.plus")
                    }
                }
            } else {
                // Create Team Button
                Section {
                    Button {
                        viewState.activeSheet = .create
                    } label: {
                        Label("Create Team", systemImage: "person.3")
                    }
                }
            }
        }
        .navigationTitle("Team Management")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $viewState.activeSheet) { sheet in
            switch sheet {
            case .invite:
                InviteTeamMemberView()
            case .create:
                CreateTeamView()
            case .share(let url):
                ShareSheet(items: [url])
            }
        }
        .alert("Error", isPresented: $viewState.showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewState.errorMessage)
        }
    }
}

class TeamManagementViewState: ObservableObject {
    @Published var activeSheet: ActiveSheet?
    @Published var showingError = false
    @Published var errorMessage = ""
    
    enum ActiveSheet: Identifiable {
        case invite
        case create
        case share(URL)
        
        var id: String {
            switch self {
            case .invite: return "invite"
            case .create: return "create"
            case .share: return "share"
            }
        }
    }
}

struct TeamInfoSection: View {
    let team: TeamManager.Team
    
    var body: some View {
        Section("Team Info") {
            HStack {
                Text("Team Name")
                Spacer()
                Text(team.name)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct TeamMembersSection: View {
    let members: [TeamManager.TeamMember]
    
    var body: some View {
        Section("Team Members") {
            ForEach(members) { member in
                TeamMemberRow(member: member)
            }
        }
    }
}

struct TeamMemberRow: View {
    let member: TeamManager.TeamMember
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(member.email)
                    .font(.headline)
                Text(member.role.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if member.role == .owner {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 