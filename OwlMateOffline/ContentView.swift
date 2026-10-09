import SwiftUI

enum OnboardingStore {
    static let tutorialCompletedKey = "OwlMate.tutorialCompleted"

    static var tutorialCompleted: Bool {
        UserDefaults.standard.bool(forKey: tutorialCompletedKey)
    }

    static func markTutorialCompleted() {
        UserDefaults.standard.set(true, forKey: tutorialCompletedKey)
    }

    static func resetTutorial() {
        UserDefaults.standard.set(false, forKey: tutorialCompletedKey)
    }
}

struct AppLaunchView: View {
    private enum Phase {
        case intro
        case tutorial
        case app
    }

    @State private var phase: Phase = .intro
    @State private var introVisible = false

    var body: some View {
        Group {
            switch phase {
            case .intro:
                AppIntroView(isVisible: introVisible)
            case .tutorial:
                TutorialView {
                    OnboardingStore.markTutorialCompleted()
                    showApp()
                }
            case .app:
                ContentView()
            }
        }
        .task {
            guard phase == .intro else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                introVisible = true
            }
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            if OnboardingStore.tutorialCompleted {
                showApp()
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    phase = .tutorial
                }
            }
        }
    }

    private func showApp() {
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .app
        }
    }
}

private struct AppIntroView: View {
    let isVisible: Bool

    var body: some View {
        ZStack {
            AppTheme.navy.ignoresSafeArea()

            // The first frame is intentionally only the official OwlMate artwork.
            OwlMateLogo(size: 148)
                .scaleEffect(isVisible ? 1 : 0.86)
                .opacity(isVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.45), value: isVisible)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("OwlMate logo")
    }
}

private struct TutorialView: View {
    let finish: () -> Void
    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let steps = [
        TutorialStep(
            title: "Learn privately",
            message: "Ask questions and explore ideas with a study buddy that runs on your device."
        ),
        TutorialStep(
            title: "Keep every conversation",
            message: "Start separate chats for different topics, then return to your saved history whenever you need it."
        ),
        TutorialStep(
            title: "Offline by design",
            message: "Your conversations stay on this iPhone. Once the model is set up, chat without an internet connection."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Welcome to OwlMate")
                    .font(.headline.weight(.semibold))
                Button("Skip", action: finish)
                    .font(.subheadline.weight(.medium))
                    .frame(minWidth: 56, minHeight: 44)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            TabView(selection: $page) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 20) {
                        Spacer(minLength: 24)

                        VStack(spacing: 10) {
                            Text(step.title)
                                .font(.title2.weight(.bold))
                                .multilineTextAlignment(.center)
                            Text(step.message)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 28)
                        }

                        Spacer(minLength: 24)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: page)

            HStack(spacing: 12) {
                Button {
                    page -= 1
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(page == 0)

                Button {
                    if page == steps.count - 1 {
                        finish()
                    } else {
                        page += 1
                    }
                } label: {
                    Text(page == steps.count - 1 ? "Get Started" : "Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(height: 50)
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        .tint(AppTheme.accent)
    }
}

private struct TutorialStep {
    let title: String
    let message: String
}

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
