import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var chatViewModel = ChatViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                onAskOwlMate: { selectedTab = .chat },
                onSelectSuggestion: { prompt in
                    chatViewModel.draft = prompt
                    selectedTab = .chat
                }
            )
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppTab.home)

            ChatView(viewModel: chatViewModel)
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(AppTab.chat)

            SettingsView(viewModel: chatViewModel)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(AppTheme.accent)
    }
}

enum AppTab: Hashable {
    case home, chat, settings
}

#Preview {
    ContentView()
}
