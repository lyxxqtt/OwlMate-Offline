import SwiftUI
import UIKit

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var modelManager = ModelManager.shared
    @State private var showingHistory = false
    @State private var copiedMessageID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            readinessBanner
            if viewModel.messages.isEmpty {
                emptyState
            } else {
                messageList
            }
            if viewModel.isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("OwlMate is thinking…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .transition(.opacity)
            }
            composer
        }
        .navigationTitle(viewModel.activeConversation?.title ?? "OwlMate")
        .task {
            await modelManager.refresh()
            await viewModel.refreshReadiness()
        }
        .onChange(of: modelManager.state) { _, newState in
            guard case .ready = newState else { return }
            Task { await viewModel.refreshReadiness() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("History", systemImage: "clock.arrow.circlepath") {
                    showingHistory = true
                }
                .accessibilityLabel("Chat history")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("New", systemImage: "square.and.pencil") {
                    viewModel.newConversation()
                }
                .disabled(viewModel.messages.isEmpty || viewModel.isGenerating)
            }
        }
        .sheet(isPresented: $showingHistory) {
            NavigationStack {
                HistoryView(viewModel: viewModel) {
                    showingHistory = false
                }
            }
        }
    }

    private var readinessBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
            Text(viewModel.readiness.title)
                .font(.caption.weight(.medium))
            Spacer()
            if case .notInstalled = modelManager.state {
                Button("Set up") {
                    modelManager.install()
                }
                .font(.caption.weight(.semibold))
            }
        }
        .foregroundStyle(modelManager.isReady ? AppTheme.success : AppTheme.warning)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background((modelManager.isReady ? AppTheme.success : AppTheme.warning).opacity(0.1))
        .alert("Local AI error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            OwlMateLogo(size: 72)
            Text("Hey, ready to learn?")
                .font(.title2.weight(.semibold))
            Text("Ask anything. Your study buddy works right on your iPhone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
            HStack {
                SuggestionButton(title: "Explain a concept") {
                    viewModel.draft = "Explain a concept to me in simple words."
                }
                SuggestionButton(title: "Help me study") {
                    viewModel.draft = "Help me study for my next lesson."
                }
                SuggestionButton(title: "Summarize my notes") {
                    viewModel.draft = "Summarize my notes: "
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private struct SuggestionButton: View {
        let title: String
        let action: () -> Void

        var body: some View {
            Button(title, action: action)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(AppTheme.lavender.opacity(0.65), in: Capsule())
                .buttonStyle(.plain)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        MessageRow(
                            message: message,
                            copiedMessageID: $copiedMessageID
                        )
                        .id(message.id)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 18)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                guard let lastID = viewModel.messages.last?.id else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask OwlMate anything...", text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
            Button(action: viewModel.sendOrStop) {
                Image(systemName: viewModel.isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title)
            }
            .disabled(!viewModel.isGenerating &&
                      (viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                       !modelManager.isReady))
        }
        .padding()
        .background(AppTheme.chatComposer)
    }
}

private struct MessageRow: View {
    let message: ChatMessage
    @Binding var copiedMessageID: UUID?

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: 48) }
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                Group {
                    if message.isUser {
                        Text(message.text)
                    } else if let markdown = try? AttributedString(
                        markdown: message.text,
                        options: .init(interpretedSyntax: .full)
                    ) {
                        Text(markdown)
                    } else {
                        Text(message.text)
                    }
                }
                .textSelection(.enabled)
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .foregroundStyle(message.isUser ? .white : .primary)
                .background(
                    message.isUser ? AppTheme.accent : AppTheme.chatAssistant,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

                if !message.isUser {
                    Button {
                        UIPasteboard.general.string = message.text
                        copiedMessageID = message.id
                    } label: {
                        Label(
                            copiedMessageID == message.id ? "Copied" : "Copy",
                            systemImage: copiedMessageID == message.id ? "checkmark" : "doc.on.doc"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Copy OwlMate response")
                }
            }
            if !message.isUser { Spacer(minLength: 48) }
        }
    }
}
