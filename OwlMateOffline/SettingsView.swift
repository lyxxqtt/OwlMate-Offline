import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var modelManager = ModelManager.shared
    @State private var showingClearHistoryConfirmation = false
    @State private var showingTutorialResetChoice = false

    var body: some View {
        NavigationStack {
            List {
                Section("Local AI") {
                    LabeledContent("Model", value: "Qwen2.5 0.5B Instruct")
                    LabeledContent("Status", value: statusText)
                    if case .downloading(let progress) = modelManager.state {
                        ProgressView(value: progress)
                        Button("Cancel download") { modelManager.cancel() }
                    } else if !modelManager.isReady {
                        Button(modelManager.state.isFailure ? "Retry model setup" : "Set up local model") {
                            modelManager.install()
                        }
                    }
                }
                Section("Privacy") {
                    Label("Conversations stay on this device.", systemImage: "lock.shield")
                    Text("OwlMate does not require an account or send study content to a remote AI service.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Chat history") {
                    Button("Clear all conversations", role: .destructive) {
                        showingClearHistoryConfirmation = true
                    }
                    .disabled(viewModel.conversations.isEmpty)
                }
                Section("About") {
                    HStack {
                        OwlMateLogo(size: 42)
                        Text("OwlMate - Offline")
                            .font(.headline)
                    }
                    LabeledContent("Version", value: "1.0")
                }
            }
            .navigationTitle("Settings")
            .task { await modelManager.refresh() }
            .confirmationDialog(
                "Clear all conversations?",
                isPresented: $showingClearHistoryConfirmation,
                titleVisibility: .visible
            ) {
                Button("Continue", role: .destructive) {
                    showingTutorialResetChoice = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes all locally saved chats. Your model and app settings will be preserved.")
            }
            .confirmationDialog(
                "Show the tutorial next time?",
                isPresented: $showingTutorialResetChoice,
                titleVisibility: .visible
            ) {
                Button("Yes, show tutorial") {
                    OnboardingStore.resetTutorial()
                    viewModel.clearAllConversations()
                }
                Button("No, keep tutorial completed") {
                    viewModel.clearAllConversations()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Would you like to show the tutorial guide again the next time you open the app?")
            }
        }
    }

    private var statusText: String {
        switch modelManager.state {
        case .notInstalled: "Not installed"
        case .downloading: "Downloading"
        case .loading: "Loading"
        case .ready: "Ready offline"
        case .failed: "Unavailable"
        }
    }
}

private extension ModelManager.State {
    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
