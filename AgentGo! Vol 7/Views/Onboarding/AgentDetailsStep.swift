import SwiftUI

struct AgentDetailsStep: View {
    @ObservedObject var viewModel: WelcomeFlowViewModel
    @Binding var currentStep: Int
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Your Details")
                    .font(.title2.bold())
                
                VStack(spacing: 16) {
                    TextField("Full Name", text: $viewModel.agentName)
                        .textContentType(.name)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Phone Number", text: $viewModel.phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("License Number", text: $viewModel.licenseNumber)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button("Continue") {
                    withAnimation {
                        currentStep = 2
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.customAccent)
            }
            .padding()
        }
    }
} 