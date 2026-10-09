import SwiftUI

struct SavedMaterialsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No saved materials",
                systemImage: "bookmark",
                description: Text("Save summaries, reviewers, and flashcards to find them here.")
            )
            .navigationTitle("Saved")
        }
    }
}
