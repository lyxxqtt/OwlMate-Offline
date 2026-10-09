import Foundation
import SwiftLlama

enum LocalAIError: LocalizedError {
    case modelNotInstalled
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .modelNotInstalled:
            "The local language model is not installed. Set it up in Settings before starting offline chat."
        case .emptyResponse:
            "The local model returned an empty response. Please try again."
        }
    }
}

actor LocalAIService {
    static let shared = LocalAIService()

    private var llama: LlamaService?
    private let modelFileName = "qwen2.5-0.5b-instruct-q4_k_m.gguf"

    var modelURL: URL {
        modelDirectory
            .appendingPathComponent(modelFileName)
    }

    var modelDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OwlMateModels", isDirectory: true)
    }

    func isModelInstalled() -> Bool {
        FileManager.default.fileExists(atPath: modelURL.path)
    }

    func loadInstalledModel() throws {
        guard isModelInstalled() else {
            throw LocalAIError.modelNotInstalled
        }

        llama = LlamaService(
            modelUrl: modelURL,
            config: LlamaConfig(batchSize: 256, maxTokenCount: 512, useGPU: true)
        )
    }

    func generateAnswer(for prompt: String) async throws -> String {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalAIError.emptyResponse
        }
        guard let llama else {
            throw LocalAIError.modelNotInstalled
        }

        let messages = [
            LlamaChatMessage(
                role: .system,
                content: "You are OwlMate, a careful and friendly offline study tutor. Explain clearly and acknowledge uncertainty."
            ),
            LlamaChatMessage(role: .user, content: prompt)
        ]
        let stream = try await llama.streamCompletion(
            of: messages,
            samplingConfig: LlamaSamplingConfig(temperature: 0.4, seed: 42)
        )

        var response = ""
        for try await token in stream {
            response += token
        }
        guard !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalAIError.emptyResponse
        }
        return response
    }

    func verifyInference() async throws {
        _ = try await generateAnswer(for: "Reply with the single word READY.")
    }

    func stopGeneration() async {
        await llama?.stopCompletion()
    }
}
