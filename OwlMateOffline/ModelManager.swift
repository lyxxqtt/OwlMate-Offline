import CryptoKit
import Foundation
import Observation

enum ModelManagerError: LocalizedError {
    case invalidSize
    case checksumMismatch
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .invalidSize:
            "The downloaded model is incomplete."
        case .checksumMismatch:
            "The downloaded model failed integrity verification."
        case .downloadFailed:
            "The model download could not be completed."
        }
    }
}

@MainActor
@Observable
final class ModelManager {
    static let shared = ModelManager()

    enum State: Equatable {
        case notInstalled
        case downloading(Double)
        case loading
        case ready
        case failed(String)
    }

    let modelName = "Qwen2.5 0.5B Instruct (Q4_K_M)"
    let approximateSize = "469 MB"
    private(set) var state: State = .notInstalled

    private let expectedSize: Int64 = 491_400_032
    private let expectedSHA256 = "74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db"
    private let sourceURL = URL(string: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf?download=true")!
    private var downloadTask: Task<Void, Never>?

    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    func refresh() async {
        if await LocalAIService.shared.isModelInstalled() {
            state = .loading
            do {
                try await LocalAIService.shared.loadInstalledModel()
                state = .ready
            } catch {
                state = .failed(error.localizedDescription)
            }
        } else {
            state = .notInstalled
        }
    }

    func install() {
        guard downloadTask == nil else { return }
        state = .downloading(0)
        downloadTask = Task {
            do {
                let modelURL = try await downloadModel()
                try validate(modelURL)
                try await LocalAIService.shared.loadInstalledModel()
                state = .loading
                try await LocalAIService.shared.verifyInference()
                state = .ready
            } catch is CancellationError {
                state = .notInstalled
            } catch {
                state = .failed(error.localizedDescription)
            }
            downloadTask = nil
        }
    }

    func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
        state = .notInstalled
    }

    private func downloadModel() async throws -> URL {
        let directory = await LocalAIService.shared.modelDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = await LocalAIService.shared.modelURL
        let temporary = directory.appendingPathComponent("model.download")
        try? FileManager.default.removeItem(at: temporary)

        let delegate = ModelDownloadDelegate { [weak self] fraction in
            Task { @MainActor in self?.state = .downloading(fraction) }
        }
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let (temporaryURL, response): (URL, URLResponse) = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                delegate.continuation = continuation
                delegate.task = session.downloadTask(with: sourceURL)
                delegate.task?.resume()
            }
        } onCancel: {
            session.invalidateAndCancel()
        }
        session.finishTasksAndInvalidate()
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ModelManagerError.downloadFailed
        }
        try FileManager.default.moveItem(at: temporaryURL, to: temporary)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }

    private func validate(_ url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber, size.int64Value == expectedSize else {
            throw ModelManagerError.invalidSize
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest == expectedSHA256 else {
            throw ModelManagerError.checksumMismatch
        }
    }
}

private final class ModelDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let progress: @MainActor (Double) -> Void
    var continuation: CheckedContinuation<(URL, URLResponse), Error>?
    var task: URLSessionDownloadTask?

    init(progress: @escaping @MainActor (Double) -> Void) {
        self.progress = progress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in progress(fraction) }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        continuation?.resume(returning: (location, downloadTask.response ?? URLResponse()))
        continuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error, continuation != nil {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
