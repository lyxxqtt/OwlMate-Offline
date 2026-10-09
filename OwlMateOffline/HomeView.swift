import SwiftUI

struct HomeView: View {
    let onAskOwlMate: () -> Void
    let onSelectSuggestion: (String) -> Void
    @State private var modelManager = ModelManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 14) {
                        OwlMateLogo(size: 60)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("OwlMate - Offline")
                                .font(.title2.weight(.bold))
                            Text("Your personal AI study buddy. Anytime. Anywhere.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("What are we learning today?")
                            .font(.largeTitle.weight(.bold))
                        Text("Ask anything. Your study buddy works right on your iPhone.")
                            .foregroundStyle(.secondary)
                    }

                    Button(action: onAskOwlMate) {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Ask OwlMate")
                                    .font(.title3.weight(.semibold))
                                Text("Start a private, offline conversation")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.title3.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(20)
                        .background(AppTheme.navy, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Start with a prompt")
                            .font(.headline)
                        FlowLayout {
                            PromptChip(title: "Explain a concept", action: {
                                onSelectSuggestion("Explain a concept to me in simple words.")
                            })
                            PromptChip(title: "Help me study", action: {
                                onSelectSuggestion("Help me make a short study plan for my next lesson.")
                            })
                            PromptChip(title: "Summarize my notes", action: {
                                onSelectSuggestion("Summarize these notes clearly: ")
                            })
                        }
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(AppTheme.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(modelManager.isReady ? "Ready for offline AI" : "Set up offline AI")
                                .font(.subheadline.weight(.semibold))
                            Text(modelManager.isReady
                                 ? "New answers are generated privately on this device."
                                 : "Download the model once to use OwlMate without internet.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .cardBackground()

                }
                .padding()
            }
            .task { await modelManager.refresh() }
        }
    }
}

private struct PromptChip: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.lavender.opacity(0.6), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct FlowLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var lineWidth: CGFloat = 0
        var height: CGFloat = 0
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > width, lineWidth > 0 {
                height += lineHeight + 8
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + 8
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
                y += lineHeight + 8
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + 8
            lineHeight = max(lineHeight, size.height)
        }
    }
}
