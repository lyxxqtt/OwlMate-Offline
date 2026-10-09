import Foundation
import Observation

enum ModelReadiness: Equatable {
    case notDownloaded
    case loading
    case ready
    case failed(String)

    var title: String {
        switch self {
        case .notDownloaded: "Model setup required"
        case .loading: "Preparing local AI"
        case .ready: "Ready for offline chat"
        case .failed: "Model unavailable"
        }
    }
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let isUser: Bool
    let createdAt: Date

    init(id: UUID = UUID(), text: String, isUser: Bool, createdAt: Date = .now) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.createdAt = createdAt
    }
}

@Observable
@MainActor
final class ChatViewModel {
    var conversations: [Conversation] = []
    var activeConversationID: UUID?
    var draft = ""
    var readiness: ModelReadiness = .notDownloaded
    var isGenerating = false
    var errorMessage: String?

    private let aiService = LocalAIService.shared
    private let store = ConversationStore.shared

    var messages: [ChatMessage] {
        activeConversation?.messages ?? []
    }

    var activeConversation: Conversation? {
        guard let activeConversationID else { return nil }
        return conversations.first { $0.id == activeConversationID }
    }

    init() {
        Task { @MainActor in
            conversations = await store.load()
            activeConversationID = conversations.first?.id
        }
    }

    func newConversation() {
        guard !isGenerating else { return }
        activeConversationID = nil
        draft = ""
        errorMessage = nil
    }

    func select(_ conversation: Conversation) {
        guard !isGenerating else { return }
        activeConversationID = conversation.id
        draft = ""
        errorMessage = nil
    }

    func delete(_ conversation: Conversation) {
        guard !isGenerating else { return }
        conversations.removeAll { $0.id == conversation.id }
        if activeConversationID == conversation.id {
            activeConversationID = conversations.first?.id
        }
        persist()
    }

    func clearAllConversations() {
        guard !isGenerating else { return }
        conversations.removeAll()
        activeConversationID = nil
        Task { try? await store.clear() }
    }

    func refreshReadiness() async {
        readiness = await aiService.isModelInstalled() ? .loading : .notDownloaded
        guard readiness == .loading else { return }
        do {
            try await aiService.loadInstalledModel()
            readiness = .ready
        } catch {
            readiness = .failed(error.localizedDescription)
        }
    }

    func send() {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGenerating else { return }
        let conversationID = activeConversationID ?? UUID()
        if activeConversationID == nil {
            conversations.insert(
                Conversation(
                    id: conversationID,
                    title: Conversation.title(for: prompt),
                    messages: [ChatMessage(text: prompt, isUser: true)]
                ),
                at: 0
            )
            activeConversationID = conversationID
        } else {
            append(ChatMessage(text: prompt, isUser: true), to: conversationID)
        }
        draft = ""
        isGenerating = true
        errorMessage = nil
        persist()

        Task { [weak self] in
            guard let self else { return }
            do {
                let answer = try await aiService.generateAnswer(for: prompt)
                guard activeConversationID == conversationID else { return }
                append(ChatMessage(text: answer, isUser: false), to: conversationID)
                persist()
            } catch {
                errorMessage = error.localizedDescription
                readiness = .failed(error.localizedDescription)
            }
            isGenerating = false
        }
    }

    func stop() {
        Task {
            await aiService.stopGeneration()
            isGenerating = false
        }
    }

    func sendOrStop() {
        isGenerating ? stop() : send()
    }

    private func append(_ message: ChatMessage, to conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].messages.append(message)
        conversations[index].updatedAt = message.createdAt
    }

    private func persist() {
        let snapshot = conversations
        Task { try? await store.save(snapshot) }
    }
}
