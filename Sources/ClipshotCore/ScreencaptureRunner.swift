import Foundation
import Synchronization

public struct ScreencaptureResult: Equatable, Sendable {
    public var exitCode: Int32
    /// Trimmed of surrounding whitespace; empty when the tool printed nothing.
    public var stderr: String

    public init(exitCode: Int32, stderr: String) {
        self.exitCode = exitCode
        self.stderr = stderr
    }
}

public enum ScreencaptureError: Error, Equatable, Sendable {
    /// The child process could not be spawned at all: missing binary, not executable.
    case launchFailed(String)
}

/// Region screenshot straight onto the clipboard: `/usr/sbin/screencapture -i -c`. The selection UI is the
/// system's own (drag a region, Space toggles window mode, Esc cancels) and the image lands on the clipboard
/// exactly as ⌃⇧⌘4 puts it there; no file is written.
///
/// The tool has `com.apple.private.tcc.check-allow-on-responsible-process`, so Screen Recording is checked
/// against the *responsible* process: spawned from Clipshot.app, Clipshot's grant is the one that counts
/// (Shotcue research §2.2).
public struct ScreencaptureRunner: Sendable {
    ///   -i interactive selection · -c to the clipboard instead of a file
    public static let arguments = ["-i", "-c"]

    public let executableURL: URL
    /// nil inherits the parent environment. Tests pass FAKE_SCREENCAPTURE_SCENARIO here.
    public let environment: [String: String]?

    public init(
        executableURL: URL = URL(fileURLWithPath: "/usr/sbin/screencapture"),
        environment: [String: String]? = nil
    ) {
        self.executableURL = executableURL
        self.environment = environment
    }

    /// Returns once the user has finished (or cancelled) the selection; the wait is as long as they take.
    public func run() async throws -> ScreencaptureResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = Self.arguments
        if let environment { process.environment = environment }
        process.standardOutput = FileHandle.nullDevice
        let errorPipe = Pipe()
        process.standardError = errorPipe

        // Drain stderr concurrently. Waiting for exit first would deadlock if the child ever filled the
        // 64 KB pipe buffer; reading first would block this task for the whole (unbounded) selection. The blocking
        // read runs on a GCD thread, not on one of Swift's few cooperative threads.
        let readEnd = errorPipe.fileHandleForReading
        let stderr = CollectedData()
        let stderrRead = DispatchGroup()
        stderrRead.enter()
        DispatchQueue.global(qos: .utility).async {
            stderr.set(((try? readEnd.readToEnd()) ?? nil) ?? Data())
            stderrRead.leave()
        }

        let exitCode: Int32
        do {
            exitCode = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Int32, Error>) in
                process.terminationHandler = { finished in
                    continuation.resume(returning: finished.terminationStatus)
                }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: ScreencaptureError.launchFailed(error.localizedDescription))
                }
            }
        } catch {
            // The child never started, so nothing holds the pipe's write end open for the reader but us.
            try? errorPipe.fileHandleForWriting.close()
            throw error
        }

        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            stderrRead.notify(queue: .global(qos: .utility)) { done.resume() }
        }
        let stderrText = String(decoding: stderr.value, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return ScreencaptureResult(exitCode: exitCode, stderr: stderrText)
    }
}

/// The bytes the stderr reader collected, handed from its GCD thread to the awaiting task.
private final class CollectedData: Sendable {
    private let storage = Mutex(Data())
    var value: Data { storage.withLock { $0 } }
    func set(_ data: Data) { storage.withLock { $0 = data } }
}
