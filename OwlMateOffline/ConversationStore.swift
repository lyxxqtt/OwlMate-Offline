import Foundation

struct Conversation: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var messages: [ChatMessage]

    var preview: String {
        messages.last?.text ?? "No messages yet"
    }

    init(
        id: UUID = UUID(),
        title: String = "New Conversation",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        messages: [ChatMessage] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

actor ConversationStore {
    static let shared = ConversationStore()

    private let fileURL: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("OwlMateConversations.json")
    }()

    private let legacyFileURL: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("OwlMateConversation.json")
    }()

    func load() -> [Conversation] {
        if let data = try? Data(contentsOf: fileURL),
           let conversations = try? JSONDecoder().decode([Conversation].self, from: data) {
            return conversations.sorted { $0.updatedAt > $1.updatedAt }
        }

        guard let data = try? Data(contentsOf: legacyFileURL),
              let messages = try? JSONDecoder().decode([ChatMessage].self, from: data),
              !messages.isEmpty else {
            return []
        }
        let migrated = Conversation(
            title: Conversation.title(for: messages.first?.text),
            messages: messages
        )
        try? save([migrated])
        return [migrated]
    }

    func save(_ conversations: [Conversation]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(conversations)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func clear() throws {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: legacyFileURL)
    }
}

extension Conversation {
    static func title(for prompt: String?) -> String {
        guard let prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "New Conversation"
        }
        let words = prompt
            .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .prefix(6)
            .map(String.init)
        guard !words.isEmpty else { return "New Conversation" }
        let normalized = words.joined(separator: " ")
        let lowercased = normalized.lowercased()
        let title: String
        if lowercased.contains("photosynthesis") {
            title = "Understanding Photosynthesis"
        } else if lowercased.contains("exam") || lowercased.contains("biology") {
            title = "Study Preparation"
        } else if lowercased.contains("summarize") || lowercased.contains("summary") {
            title = "Lesson Summary"
        } else {
            title = normalized
        }
        return title.prefix(1).uppercased() + title.dropFirst()
    }
}
