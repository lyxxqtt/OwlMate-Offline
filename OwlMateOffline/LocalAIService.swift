import Foundation
import SwiftLlama

enum LocalAIError: LocalizedError {
    case modelNotInstalled
    case emptyResponse
    case contextTooLong

    var errorDescription: String? {
        switch self {
        case .modelNotInstalled:
            "The local language model is not installed. Set it up in Settings before starting offline chat."
        case .emptyResponse:
            "The local model returned an empty response. Please try again."
        case .contextTooLong:
            "This conversation is too long for the local model. Start a new chat or try a shorter question."
        }
    }
}

actor LocalAIService {
    static let shared = LocalAIService()

    private var llama: LlamaService?
    private let modelFileName = "qwen2.5-0.5b-instruct-q4_k_m.gguf"
    private let maximumContextCharacters = 12_000

    var modelURL: URL {
        modelDirectory
            .appendingPathComponent(modelFileName)
    }

    var modelDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OwlMateModels", isDirectory: true)
    }

    func isModelInstalled() -> Bool {
        guard FileManager.default.fileExists(atPath: modelURL.path) else { return false }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: modelURL.path) else {
            return false
        }
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0 > 0
    }

    func loadInstalledModel() throws {
        guard isModelInstalled() else {
            throw LocalAIError.modelNotInstalled
        }

        guard llama == nil else { return }
        llama = LlamaService(
            modelUrl: modelURL,
            config: LlamaConfig(batchSize: 256, maxTokenCount: 512, useGPU: true)
        )
    }

    func generateAnswer(for messages: [LlamaChatMessage]) async throws -> String {
        guard messages.contains(where: {
            $0.role == .user && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            throw LocalAIError.emptyResponse
        }
        guard let llama else {
            throw LocalAIError.modelNotInstalled
        }

        let context = messages.reduce(into: 0) { $0 += $1.content.count }
        guard context <= maximumContextCharacters else {
            throw LocalAIError.contextTooLong
        }
        let stream = try await llama.streamCompletion(
            of: messages,
            samplingConfig: LlamaSamplingConfig(temperature: 0.4, seed: 42)
        )

        var tokens: [String] = []
        tokens.reserveCapacity(128)
        for try await token in stream {
            try Task.checkCancellation()
            tokens.append(token)
        }
        let response = tokens.joined()
        guard !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalAIError.emptyResponse
        }
        return response
    }

    func verifyInference() async throws {
        _ = try await generateAnswer(for: [
            LlamaChatMessage(
                role: .system,
                content: "You are OwlMate, a careful and friendly offline study tutor. Explain clearly and acknowledge uncertainty."
            ),
            LlamaChatMessage(role: .user, content: "Reply with the single word READY.")
        ])
    }

    func stopGeneration() async {
        await llama?.stopCompletion()
    }
}
