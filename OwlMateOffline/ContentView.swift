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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) {
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

            Circle()
                .fill(AppTheme.accent.opacity(isVisible ? 0.18 : 0))
                .frame(width: 280, height: 280)
                .blur(radius: 36)
                .scaleEffect(isVisible ? 1 : 0.7)
                .animation(.easeOut(duration: 0.7), value: isVisible)

            // The first frame is intentionally only the official OwlMate artwork.
            OwlMateLogo(size: 148)
                .scaleEffect(isVisible ? 1 : 0.86)
                .opacity(isVisible ? 1 : 0)
                .shadow(color: AppTheme.accent.opacity(isVisible ? 0.25 : 0), radius: 24)
                .animation(.spring(response: 0.55, dampingFraction: 0.78), value: isVisible)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("OwlMate logo")
    }
}

private struct TutorialView: View {
    let finish: () -> Void
    @State private var page = 0
    @State private var contentVisible = false
    @State private var isNextPressed = false
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
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Welcome to")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("OwlMate")
                        .font(.headline.weight(.bold))
                }
                Button("Skip", action: finish)
                    .font(.subheadline.weight(.medium))
                    .frame(minWidth: 56, minHeight: 44)
                    .accessibilityHint("Skip the introduction")
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            TabView(selection: $page) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 20) {
                        Spacer(minLength: 24)

                        TutorialVisual(index: index, isVisible: contentVisible)

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
                        .offset(y: contentVisible ? 0 : 12)
                        .opacity(contentVisible ? 1 : 0)

                        Spacer(minLength: 24)
                    }
                    .id(index)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: page)
            .onChange(of: page) { _, _ in
                contentVisible = false
                withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) {
                    contentVisible = true
                }
            }

            HStack(spacing: 12) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        page -= 1
                    }
                } label: {
                    Label("Back", systemImage: "arrow.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(page == 0)

                Button {
                    if page == steps.count - 1 {
                        finish()
                    } else {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            page += 1
                        }
                    }
                } label: {
                    Label(
                        page == steps.count - 1 ? "Get Started" : "Next",
                        systemImage: page == steps.count - 1 ? "sparkles" : "arrow.right"
                    )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .scaleEffect(isNextPressed ? 0.97 : 1)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !reduceMotion else { return }
                            withAnimation(.easeOut(duration: 0.1)) {
                                isNextPressed = true
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                isNextPressed = false
                            }
                        }
                )
            }
            .frame(height: 50)
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        .tint(AppTheme.accent)
        .onAppear {
            if reduceMotion {
                contentVisible = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.08)) {
                    contentVisible = true
                }
            }
        }
    }
}

private struct TutorialVisual: View {
    let index: Int
    let isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if index == 0 {
                // The official icons.svg artwork is surfaced on the first guide page.
                OwlMateLogo(size: 118)
                    .padding(18)
                    .background(.thinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(AppTheme.accent.opacity(0.22), lineWidth: 1)
                    }
                    .shadow(color: AppTheme.accent.opacity(0.16), radius: 22, y: 10)
            } else {
                Image(systemName: index == 1 ? "bubble.left.and.bubble.right.fill" : "lock.shield.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 118, height: 118)
                    .background(AppTheme.lavenderSurface, in: Circle())
            }
        }
        .scaleEffect(isVisible ? 1 : 0.76)
        .opacity(isVisible ? 1 : 0)
        .rotationEffect(.degrees(isVisible || reduceMotion ? 0 : -5))
        .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.72), value: isVisible)
        .accessibilityHidden(index != 0)
    }
}

private struct TutorialStep {
    let title: String
    let message: String
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var chatViewModel = ChatViewModel()
    @State private var showingTutorial = false

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

                SettingsView(
                    viewModel: chatViewModel,
                    onShowTutorial: { showingTutorial = true }
                )
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(AppTheme.accent)
        .fullScreenCover(isPresented: $showingTutorial) {
                TutorialView {
                    OnboardingStore.markTutorialCompleted()
                    showingTutorial = false
                }
        }
    }
}

enum AppTab: Hashable {
    case home, chat, settings
}

#Preview {
    ContentView()
}
