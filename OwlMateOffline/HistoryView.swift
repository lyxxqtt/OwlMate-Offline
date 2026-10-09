import SwiftUI

struct HistoryView: View {
    @Bindable var viewModel: ChatViewModel
    let onSelect: () -> Void
    @State private var searchText = ""
    @State private var pendingDelete: Conversation?

    private var filteredConversations: [Conversation] {
        guard !searchText.isEmpty else { return viewModel.conversations }
        return viewModel.conversations.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.messages.contains { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        List {
            if filteredConversations.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No chat history" : "No matching chats",
                    systemImage: searchText.isEmpty ? "bubble.left.and.bubble.right" : "magnifyingglass",
                    description: Text(searchText.isEmpty
                                      ? "Start a conversation and it will be saved here."
                                      : "Try a different search.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredConversations) { conversation in
                    Button {
                        viewModel.select(conversation)
                        onSelect()
                    } label: {
                        ConversationRow(conversation: conversation)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            pendingDelete = conversation
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Chat History")
        .searchable(text: $searchText, prompt: "Search chats")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("New Chat", systemImage: "square.and.pencil") {
                    viewModel.newConversation()
                    onSelect()
                }
            }
        }
        .confirmationDialog(
            "Delete this conversation?",
            item: $pendingDelete
        ) { conversation in
            Button("Delete", role: .destructive) {
                viewModel.delete(conversation)
            }
        }
    }
}

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(conversation.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(conversation.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(conversation.preview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 5)
    }
}
