import SwiftUI

struct HomeView: View {
    let onAskOwlMate: () -> Void
    let onSelectSuggestion: (String) -> Void
    @State private var modelManager = ModelManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HomeBrandHeader()
                        .padding(.bottom, 42)

                    HomeHero()
                        .padding(.bottom, 25)

                    AskOwlMateCard(action: onAskOwlMate)
                        .padding(.bottom, 32)

                    StarterPrompts { prompt in
                        onSelectSuggestion(prompt)
                    }
                    .padding(.bottom, 30)

                    OfflineStatusCard(
                        state: modelManager.state,
                        setupAction: modelManager.install
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 28)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.homeBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                await modelManager.refresh()
            }
        }
    }
}

private struct HomeBrandHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            OwlMateLogo(size: 62)

            VStack(alignment: .leading, spacing: 4) {
                Text("OwlMate - Offline")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Text("Your personal AI study buddy. Anytime. Anywhere.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("OwlMate Offline, your personal AI study buddy")
    }
}

private struct HomeHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("What are we learning today?")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Ask anything. Your study buddy works right on your iPhone.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AskOwlMateCard: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ask OwlMate")
                        .font(.title3.weight(.bold))
                    Text("Start a private, offline conversation")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                }

                Spacer(minLength: 12)

                Image(systemName: "arrow.up.right")
                    .font(.title2.weight(.bold))
                    .frame(width: 42, height: 42)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 21)
            .padding(.vertical, 22)
            .background(AppTheme.navy, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .scaleEffect(isPressed ? 0.98 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.12)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.16)) { isPressed = false }
                }
        )
        .accessibilityLabel("Ask OwlMate")
        .accessibilityHint("Opens a private offline conversation")
    }
}

private struct StarterPrompts: View {
    let selectPrompt: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    private let prompts = [
        ("Explain a concept", "Explain a concept to me step by step."),
        ("Help me study", "Help me study a topic using practice questions."),
        ("Summarize my notes", "Help me summarize my notes. I'll provide the text.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Start with a prompt")
                .font(.headline.weight(.semibold))

            FlowLayout(spacing: 9) {
                ForEach(prompts, id: \.0) { prompt in
                    Button(prompt.0) {
                        selectPrompt(prompt.1)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 11)
                    .background(
                        colorScheme == .dark
                        ? AppTheme.lavenderSurfaceDark
                        : AppTheme.lavenderSurface,
                        in: Capsule()
                    )
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens Chat with an editable starter prompt")
                }
            }
        }
    }
}

private struct OfflineStatusCard: View {
    let state: ModelManager.State
    let setupAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            statusIcon
                .frame(width: 25, height: 25)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if case .notInstalled = state {
                    Button("Set up offline AI", action: setupAction)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(.top, 3)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(AppTheme.statusSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.success)
        case .downloading:
            ProgressView()
                .controlSize(.small)
        case .loading:
            ProgressView()
                .controlSize(.small)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppTheme.warning)
        case .notInstalled:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(AppTheme.accent)
        }
    }

    private var title: String {
        switch state {
        case .ready: "Ready for offline AI"
        case .downloading: "Downloading offline AI"
        case .loading: "Preparing offline AI"
        case .failed: "Offline AI needs attention"
        case .notInstalled: "Set up offline AI"
        }
    }

    private var subtitle: String {
        switch state {
        case .ready:
            "New answers are generated privately on this device."
        case .downloading(let progress):
            "Downloading the local model: \(Int(progress * 100))% complete."
        case .loading:
            "Loading the local model. This may take a moment."
        case .failed(let message):
            message
        case .notInstalled:
            "Download the model once to use OwlMate without internet."
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var lineWidth: CGFloat = 0
        var height: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > width, lineWidth > 0 {
                height += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: height + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
