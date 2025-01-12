import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @AppStorage("defaultOpenHomeStartTime") private var defaultStartTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @AppStorage("defaultBufferDuration") private var defaultBufferDuration = 5
    @Environment(\.dismiss) private var dismiss
    @State private var showingLogoutAlert = false
    @State private var showingLoginView = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.colorScheme) var systemColorScheme
    @State private var showingImageOptions = false
    
    var body: some View {
        NavigationStack {
            Form {
                VStack {
                    Button {
                        showingImageOptions = true
                    } label: {
                        if let profileImage = viewModel.userProfileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.customAccent, lineWidth: 2))
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 120, height: 120)
                                .foregroundStyle(Color.customAccent)
                        }
                    }
                    .confirmationDialog("Profile Image Options", isPresented: $showingImageOptions, titleVisibility: .visible) {
                        PhotosPicker(selection: $viewModel.selectedItem,
                                   matching: .images,
                                   photoLibrary: .shared()) {
                            Text("Add from Camera Roll")
                        }
                        
                        Button("Use Camera") {
                            // Camera functionality will be added later
                        }
                        
                        if viewModel.userProfileImage != nil {
                            Button("Delete Image", role: .destructive) {
                                Task {
                                    try? await viewModel.deleteProfileImage()
                                }
                            }
                        }
                        
                        Button("Cancel", role: .cancel) { }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                
                Section {
                    Toggle(isOn: $isDarkMode) {
                        Label {
                            Text("Dark Mode")
                        } icon: {
                            Image(systemName: isDarkMode ? "moon.fill" : "moon")
                        }
                    }
                    .onChange(of: isDarkMode) { _ in
                        setAppearance()
                    }
                } header: {
                    Text("Appearance")
                }
                
                Section {
                    DatePicker(
                        "Default Start Time",
                        selection: $defaultStartTime,
                        displayedComponents: .hourAndMinute
                    )
                    
                    Picker("Default Buffer Duration", selection: $defaultBufferDuration) {
                        Text("No Buffer").tag(0)
                        ForEach(Array(stride(from: 5, through: 30, by: 5)), id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                    
                    Picker("Default Open Home Duration", selection: $viewModel.defaultDuration) {
                        ForEach([15, 30, 45, 60, 75, 90], id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                } header: {
                    Text("Default Times")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("About AgentGo!")
                            .font(.headline)
                        Text("Version 1.0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        HStack {
                            Text("Log Out")
                            Spacer()
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                
                NavigationLink {
                    TeamManagementView()
                } label: {
                    Label("Team Management", systemImage: "person.3")
                }
            }
            .background(systemColorScheme == .dark ? Color(.systemBackground) : Color(hex: "f2efeb"))
            .toolbarBackground(systemColorScheme == .dark ? Color(.systemBackground) : Color(hex: "f2efeb"), for: .navigationBar)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Log Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    logout()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .fullScreenCover(isPresented: $showingLoginView) {
                LoginView()
            }
        }
        .onAppear {
            // Initialize based on system setting if not yet set
            if UserDefaults.standard.object(forKey: "isDarkMode") == nil {
                isDarkMode = systemColorScheme == .dark
            }
            viewModel.loadProfileImage()
        }
    }
    
    private func logout() {
        do {
            try AuthenticationService.shared.signOut()
            showingLoginView = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func setAppearance() {
        // Set the window's appearance
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
            }
        }
    }
}

#Preview {
    SettingsView()
} 