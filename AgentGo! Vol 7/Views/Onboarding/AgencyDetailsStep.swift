import SwiftUI

struct AgencyDetailsStep: View {
    @ObservedObject var viewModel: WelcomeFlowViewModel
    @Binding var currentStep: Int
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Agency Details")
                    .font(.title2.bold())
                
                VStack(spacing: 16) {
                    TextField("Agency Name", text: $viewModel.agencyName)
                        .textContentType(.organizationName)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Agency Address", text: $viewModel.agencyAddress)
                        .textContentType(.fullStreetAddress)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button("Continue") {
                    withAnimation {
                        currentStep = 3
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.customAccent)
            }
            .padding()
        }
    }
} 