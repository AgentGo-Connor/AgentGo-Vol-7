import SwiftUI

struct PreferencesStep: View {
    @ObservedObject var viewModel: WelcomeFlowViewModel
    let onComplete: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Default Settings")
                    .font(.title2.bold())
                
                VStack(spacing: 16) {
                    Picker("Default Open Home Duration", selection: $viewModel.defaultOpenHomeDuration) {
                        ForEach([15, 30, 45, 60, 75, 90], id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Default Buffer Time", selection: $viewModel.defaultBufferTime) {
                        Text("No Buffer").tag(0)
                        ForEach(Array(stride(from: 5, through: 30, by: 5)), id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Button("Complete Setup") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .tint(.customAccent)
            }
            .padding()
        }
    }
} 