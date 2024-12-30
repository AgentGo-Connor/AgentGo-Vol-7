import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @AppStorage("defaultOpenHomeStartTime") private var defaultStartTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @AppStorage("defaultBufferDuration") private var defaultBufferDuration = 5
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Dark Mode", isOn: $viewModel.isDarkMode)
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
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
} 