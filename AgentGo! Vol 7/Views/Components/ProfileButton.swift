import SwiftUI
import PhotosUI

struct ProfileButton: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showingSettings = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Button {
            showingSettings = true
        } label: {
            if isLoading {
                ProgressView()
                    .frame(width: 36, height: 36)
            } else if let profileImage = viewModel.userProfileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.customAccent, lineWidth: 2))
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(Color.customAccent)
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .onChange(of: selectedItem) { newItem in
            guard let item = newItem else { return }
            isLoading = true
            
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not load image data"])
                    }
                    
                    try await viewModel.uploadProfileImage(image)
                    
                    await MainActor.run {
                        isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            viewModel.loadProfileImage()
        }
    }
} 