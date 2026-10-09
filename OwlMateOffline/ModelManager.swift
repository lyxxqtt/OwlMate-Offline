import CryptoKit
import Foundation
import Observation

enum ModelManagerError: LocalizedError {
    case invalidSize
    case checksumMismatch
    case downloadFailed
    case fileOperation(String)

    var errorDescription: String? {
        switch self {
        case .invalidSize:
            "The downloaded model is incomplete."
        case .checksumMismatch:
            "The downloaded model failed integrity verification."
        case .downloadFailed:
            "The model download could not be completed."
        case .fileOperation(let details):
            "The model file could not be installed: \(details)"
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
    private var isRefreshing = false

    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let modelURL = await LocalAIService.shared.modelURL
        if FileManager.default.fileExists(atPath: modelURL.path) {
            state = .loading
            do {
                try validate(modelURL)
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
        let staging = directory.appendingPathComponent("\(UUID().uuidString).download")
        removeIfPresent(staging)

        let delegate = ModelDownloadDelegate(stagingURL: staging) { [weak self] fraction in
            Task { @MainActor in self?.state = .downloading(fraction) }
        }
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 3_600
        configuration.waitsForConnectivity = true
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        let (stagedURL, response): (URL, URLResponse) = try await withTaskCancellationHandler {
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
            removeIfPresent(stagedURL)
            throw ModelManagerError.downloadFailed
        }
        try validate(stagedURL)
        removeIfPresent(destination)
        do {
            try FileManager.default.moveItem(at: stagedURL, to: destination)
        } catch {
            removeIfPresent(stagedURL)
            throw ModelManagerError.fileOperation(error.localizedDescription)
        }
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

    private func removeIfPresent(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

private final class ModelDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let stagingURL: URL
    let progress: @MainActor (Double) -> Void
    var continuation: CheckedContinuation<(URL, URLResponse), Error>?
    var task: URLSessionDownloadTask?

    init(stagingURL: URL, progress: @escaping @MainActor (Double) -> Void) {
        self.stagingURL = stagingURL
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
        do {
            try? FileManager.default.removeItem(at: stagingURL)
            try FileManager.default.moveItem(at: location, to: stagingURL)
            continuation?.resume(returning: (stagingURL, downloadTask.response ?? URLResponse()))
        } catch {
            continuation?.resume(throwing: ModelManagerError.fileOperation(error.localizedDescription))
        }
        continuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error, continuation != nil {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
