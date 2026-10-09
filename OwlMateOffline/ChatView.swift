import SwiftUI
import UIKit

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var modelManager = ModelManager.shared
    @State private var showingHistory = false
    @State private var copiedMessageID: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppTheme.chatBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ChatHeader(
                    title: viewModel.activeConversation?.title ?? "OwlMate",
                    isReady: modelManager.isReady,
                    readiness: viewModel.readiness,
                    canSetUp: needsModelSetup,
                    setupAction: modelManager.install
                )

                if viewModel.messages.isEmpty {
                    EmptyChatView { prompt in
                        viewModel.draft = prompt
                    }
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.98).combined(with: .opacity))
                } else {
                    messageList
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel("Chat history")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.newConversation()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .disabled(viewModel.messages.isEmpty)
                .accessibilityLabel("New chat")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatComposer(
                draft: $viewModel.draft,
                isGenerating: viewModel.isGenerating,
                isReady: modelManager.isReady,
                sendAction: viewModel.sendOrStop
            )
        }
        .task {
            await modelManager.refresh()
            await viewModel.refreshReadiness()
        }
        .onChange(of: modelManager.state) { _, newState in
            guard case .ready = newState else { return }
            Task { await viewModel.refreshReadiness() }
        }
        .sheet(isPresented: $showingHistory) {
            NavigationStack {
                HistoryView(viewModel: viewModel) {
                    showingHistory = false
                }
            }
        }
        .alert("Local AI error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            if viewModel.failedPrompt != nil {
                Button("Retry") {
                    viewModel.retryLastRequest()
                }
            }
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 22) {
                    ForEach(viewModel.messages) { message in
                        ChatMessageView(
                            message: message,
                            copiedMessageID: $copiedMessageID
                        )
                        .id(message.id)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }

                    if viewModel.isGenerating {
                        GenerationIndicator()
                            .id("generation-indicator")
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToLatest(using: proxy)
            }
            .onChange(of: viewModel.isGenerating) { _, generating in
                guard generating else { return }
                scrollToLatest(using: proxy)
            }
        }
    }

    private var needsModelSetup: Bool {
        switch modelManager.state {
        case .notInstalled, .failed:
            return true
        case .downloading, .loading, .ready:
            return false
        }
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        guard let lastID = viewModel.messages.last?.id else { return }
        if reduceMotion {
            proxy.scrollTo(lastID, anchor: .bottom)
        } else {
            withAnimation(.easeOut(duration: 0.24)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}

private struct ChatHeader: View {
    let title: String
    let isReady: Bool
    let readiness: ModelReadiness
    let canSetUp: Bool
    let setupAction: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            OwlMateAvatar(size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Label(
                    isReady ? "On-device AI ready" : readiness.title,
                    systemImage: isReady ? "checkmark.circle.fill" : "circle.dashed"
                )
                .font(.caption2.weight(.medium))
                .foregroundStyle(isReady ? AppTheme.success : AppTheme.warning)
            }

            Spacer()

            if canSetUp {
                Button("Set up", action: setupAction)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityLabel("Set up offline AI model")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.45)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(isReady ? "On-device AI ready" : readiness.title)")
    }
}

struct OwlMateAvatar: View {
    var size: CGFloat = 36

    var body: some View {
        Image("OwlMateLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .background(AppTheme.avatarSurface, in: Circle())
            .clipShape(Circle())
            .accessibilityLabel("OwlMate")
    }
}

private struct EmptyChatView: View {
    let selectPrompt: (String) -> Void

    private let prompts = [
        ("Explain a concept", "Explain a concept to me in simple words."),
        ("Help me study", "Help me study for my next lesson."),
        ("Summarize my notes", "Summarize my notes: ")
    ]

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            OwlMateAvatar(size: 78)

            VStack(spacing: 8) {
                Text("What are we learning today?")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Your personal offline study buddy is ready to help you explore new ideas.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 10) {
                ForEach(prompts, id: \.0) { prompt in
                    Button {
                        selectPrompt(prompt.1)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: icon(for: prompt.0))
                                .frame(width: 20)
                                .foregroundStyle(AppTheme.accent)
                            Text(prompt.0)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(AppTheme.separator, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Adds this prompt to the message composer")
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func icon(for prompt: String) -> String {
        switch prompt {
        case "Help me study": "book.closed"
        case "Summarize my notes": "text.alignleft"
        default: "lightbulb"
        }
    }
}

private struct ChatMessageView: View {
    let message: ChatMessage
    @Binding var copiedMessageID: UUID?

    var body: some View {
        if message.isUser {
            HStack {
                Spacer(minLength: 52)
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
        } else {
            HStack(alignment: .top, spacing: 11) {
                OwlMateAvatar(size: 34)

                VStack(alignment: .leading, spacing: 8) {
                    assistantText
                    Button {
                        UIPasteboard.general.string = message.text
                        copiedMessageID = message.id
                    } label: {
                        Label(
                            copiedMessageID == message.id ? "Copied" : "Copy",
                            systemImage: copiedMessageID == message.id ? "checkmark" : "doc.on.doc"
                        )
                        .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(copiedMessageID == message.id ? AppTheme.success : .secondary)
                    .accessibilityLabel("Copy OwlMate response")
                }

                Spacer(minLength: 20)
            }
        }
    }

    private var assistantText: some View {
        Group {
            if let markdown = try? AttributedString(
                markdown: message.text,
                options: .init(interpretedSyntax: .full)
            ) {
                Text(markdown)
            } else {
                Text(message.text)
            }
        }
        .font(.body)
        .lineSpacing(4)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(AppTheme.separator, lineWidth: 1)
        }
    }
}

private struct GenerationIndicator: View {
    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            OwlMateAvatar(size: 34)
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Thinking")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            Spacer(minLength: 20)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("OwlMate is thinking")
    }
}

private struct ChatComposer: View {
    @Binding var draft: String
    let isGenerating: Bool
    let isReady: Bool
    let sendAction: () -> Void

    private var canSend: Bool {
        isGenerating || (isReady && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask OwlMate anything...", text: $draft, axis: .vertical)
                .font(.body)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .accessibilityLabel("Message")

            Button(action: sendAction) {
                Image(systemName: isGenerating ? "stop.fill" : "arrow.up")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(canSend ? .white : .secondary)
                    .frame(width: 34, height: 34)
                    .background(canSend ? AppTheme.accent : AppTheme.separator, in: Circle())
            }
            .disabled(!canSend)
            .accessibilityLabel(isGenerating ? "Stop generating" : "Send message")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(AppTheme.chatComposer, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.separator, lineWidth: 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
