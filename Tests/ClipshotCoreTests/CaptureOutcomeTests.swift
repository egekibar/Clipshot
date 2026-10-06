import Testing

@testable import ClipshotCore

@Suite("CaptureOutcome")
struct CaptureOutcomeTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let exitCode: Int32
        let stderr: String
        let clipboardChanged: Bool
        let want: CaptureOutcome
        let why: String
        var testDescription: String { why }
    }

    static let cases: [Case] = [
        Case(exitCode: 0, stderr: "", clipboardChanged: true, want: .copied, why: "selection landed on the clipboard"),
        Case(
            exitCode: 0, stderr: "", clipboardChanged: false, want: .cancelled,
            why: "exit 0 without a clipboard write: nothing was selected"),
        Case(exitCode: 1, stderr: "", clipboardChanged: false, want: .cancelled, why: "Esc: exit 1, empty stderr"),
        Case(
            exitCode: 1, stderr: "", clipboardChanged: true, want: .cancelled,
            why: "Esc while another app wrote to the clipboard"),
        Case(
            exitCode: 1, stderr: "could not create image from display", clipboardChanged: false,
            want: .failed(exitCode: 1, stderr: "could not create image from display"),
            why: "exit 1 with a message is a real failure"),
        Case(
            exitCode: 2, stderr: "", clipboardChanged: false, want: .failed(exitCode: 2, stderr: ""),
            why: "any other exit code is a failure"),
    ]

    @Test(arguments: cases)
    func classifiesAFinishedRun(_ c: Case) {
        #expect(
            CaptureOutcome.classify(exitCode: c.exitCode, stderr: c.stderr, clipboardChanged: c.clipboardChanged)
                == c.want)
    }
}
