import SwiftUI

struct StudyToolsView: View {
    @State private var input = ""
    @State private var selectedTool = "Summarize"

    private let tools = ["Summarize", "Simplify", "Practice quiz", "Flashcards", "Reviewer"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Choose a tool") {
                    Picker("Tool", selection: $selectedTool) {
                        ForEach(tools, id: \.self) { Text($0) }
                    }
                }
                Section("Your lesson or topic") {
                    TextEditor(text: $input)
                        .frame(minHeight: 150)
                    Text("The local model will process this on your device after setup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Generate \(selectedTool)") {}
                        .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Study tools")
        }
    }
}
