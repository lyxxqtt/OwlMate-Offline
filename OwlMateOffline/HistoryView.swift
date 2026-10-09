import SwiftUI

struct HistoryView: View {
    @Bindable var viewModel: ChatViewModel
    let onSelect: () -> Void
    @State private var searchText = ""
    @State private var pendingDelete: Conversation?
    @State private var conversationToRename: Conversation?
    @State private var renameText = ""

    private var filteredConversations: [Conversation] {
        guard !searchText.isEmpty else { return viewModel.conversations }
        return viewModel.conversations.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.messages.contains { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var groupedConversations: [(String, [Conversation])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredConversations) { conversation in
            if calendar.isDateInToday(conversation.updatedAt) { return "Today" }
            if calendar.isDateInYesterday(conversation.updatedAt) { return "Yesterday" }
            if let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: .now),
               conversation.updatedAt >= sevenDaysAgo {
                return "Previous 7 Days"
            }
            return "Earlier"
        }
        let order = ["Today", "Yesterday", "Previous 7 Days", "Earlier"]
        return order.compactMap { key in
            guard let conversations = grouped[key], !conversations.isEmpty else { return nil }
            return (key, conversations)
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
                ForEach(groupedConversations, id: \.0) { group in
                    Section(group.0) {
                        ForEach(group.1) { conversation in
                            conversationRow(conversation)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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
        .alert("Rename conversation", isPresented: renamePresented) {
            TextField("Conversation title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let conversationToRename {
                    viewModel.rename(conversationToRename, to: renameText)
                }
            }
            .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Choose a short title that will be saved on this device.")
        }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        Button {
            viewModel.select(conversation)
            onSelect()
        } label: {
            ConversationRow(
                conversation: conversation,
                isSelected: viewModel.activeConversationID == conversation.id
            )
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button(role: .destructive) {
                pendingDelete = conversation
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                renameText = conversation.title
                conversationToRename = conversation
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                pendingDelete = conversation
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var renamePresented: Binding<Bool> {
        Binding(
            get: { conversationToRename != nil },
            set: { if !$0 { conversationToRename = nil } }
        )
    }
}

private struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "bubble.left.and.bubble.right.fill" : "bubble.left")
                .foregroundStyle(isSelected ? AppTheme.accent : .secondary)
                .frame(width: 24)

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
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}
