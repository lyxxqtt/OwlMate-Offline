import Foundation
import Observation
import SwiftLlama

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
    private(set) var failedPrompt: String?
    private var generationID: UUID?

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
            do {
                conversations = try await store.load()
                activeConversationID = conversations.first?.id
            } catch {
                errorMessage = "Unable to load chat history: \(error.localizedDescription)"
            }
        }
    }

    func newConversation() {
        cancelActiveGeneration()
        activeConversationID = nil
        draft = ""
        errorMessage = nil
    }

    func select(_ conversation: Conversation) {
        cancelActiveGeneration()
        activeConversationID = conversation.id
        draft = ""
        errorMessage = nil
    }

    func rename(_ conversation: Conversation, to title: String) {
        guard !isGenerating else { return }
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty,
              let index = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            return
        }
        conversations[index].title = String(cleanedTitle.prefix(80))
        persist()
    }

    func delete(_ conversation: Conversation) {
        if activeConversationID == conversation.id {
            cancelActiveGeneration()
        }
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
        Task { [weak self] in
            guard let self else { return }
            do {
                try await store.clear()
            } catch {
                self.errorMessage = "Unable to clear chat history: \(error.localizedDescription)"
            }
        }
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
        failedPrompt = nil
        let requestID = UUID()
        generationID = requestID
        persist()

        generateAnswer(for: prompt, in: conversationID, requestID: requestID)
    }

    func retryLastRequest() {
        guard let failedPrompt, let activeConversationID, !isGenerating else { return }
        errorMessage = nil
        let requestID = UUID()
        generationID = requestID
        generateAnswer(for: failedPrompt, in: activeConversationID, requestID: requestID)
    }

    func stop() {
        cancelActiveGeneration()
    }

    func sendOrStop() {
        isGenerating ? stop() : send()
    }

    private func append(_ message: ChatMessage, to conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].messages.append(message)
        conversations[index].updatedAt = message.createdAt
    }

    private func cancelActiveGeneration() {
        guard isGenerating else {
            generationID = nil
            return
        }
        generationID = nil
        isGenerating = false
        Task {
            await aiService.stopGeneration()
        }
    }

    private func persist() {
        let snapshot = conversations
        Task { [weak self] in
            guard let self else { return }
            do {
                try await store.save(snapshot)
            } catch {
                self.errorMessage = "Unable to save chat history: \(error.localizedDescription)"
            }
        }
    }

    private func generateAnswer(for prompt: String, in conversationID: UUID, requestID: UUID) {
        isGenerating = true
        let context = contextMessages(for: conversationID)
        Task { [weak self] in
            guard let self else { return }
            do {
                let answer = try await aiService.generateAnswer(for: context)
                if activeConversationID == conversationID, generationID == requestID {
                    append(ChatMessage(text: answer, isUser: false), to: conversationID)
                    failedPrompt = nil
                    persist()
                }
            } catch {
                if activeConversationID == conversationID, generationID == requestID {
                    failedPrompt = prompt
                    errorMessage = error.localizedDescription
                    if let localError = error as? LocalAIError,
                       case .modelNotInstalled = localError {
                        readiness = .failed(error.localizedDescription)
                    }
                }
            }
            if generationID == requestID {
                isGenerating = false
            }
        }
    }

    private func contextMessages(for conversationID: UUID) -> [LlamaChatMessage] {
        let system = LlamaChatMessage(
            role: .system,
            content: "You are OwlMate, a careful and friendly offline study tutor. Explain clearly and acknowledge uncertainty."
        )
        guard let conversation = conversations.first(where: { $0.id == conversationID }) else {
            return [system]
        }
        let budget = 11_000
        var used = 0
        var selected: [LlamaChatMessage] = []
        for message in conversation.messages.reversed() {
            let content = message.text
            if used + content.count > budget {
                if selected.isEmpty {
                    let truncated = String(content.prefix(budget))
                    selected.append(
                        LlamaChatMessage(
                            role: message.isUser ? .user : .assistant,
                            content: truncated
                        )
                    )
                }
                break
            }
            selected.append(
                LlamaChatMessage(role: message.isUser ? .user : .assistant, content: content)
            )
            used += content.count
        }
        return [system] + selected.reversed()
    }
}
