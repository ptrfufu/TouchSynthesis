import Network
import XCTest

final class LegacyRunnerTests: XCTestCase {
    @MainActor
    func testExecuteTouchSynthesisJob() async throws {
        executionTimeAllowance = 60
        let connection = NWConnection(host: LegacyRunnerLink.host, port: LegacyRunnerLink.port, using: .tcp)
        defer { connection.cancel() }
        connection.start(queue: .main)

        guard let job = try await receiveJob(from: connection) else { return }
        let reply: LegacyRunnerResult
        do {
            reply = try execute(job)
        } catch {
            reply = LegacyRunnerResult(png: nil, error: error.localizedDescription)
        }
        let sent = XCTestExpectation(description: "Send job result to TouchSynthesis")
        var sendError: Error?
        LegacyRunnerLink.send(reply, over: connection, limit: LegacyRunnerLink.maxResultSize) {
            sendError = $0
            sent.fulfill()
        }
        guard await XCTWaiter.fulfillment(of: [sent], timeout: 8) == .completed else {
            throw JobError.resultTimedOut
        }
        if let sendError { throw sendError }
        if let error = reply.error { XCTFail(error) }
    }

    @MainActor
    private func receiveJob(from connection: NWConnection) async throws -> LegacyRunnerJob? {
        let received = XCTestExpectation(description: "Receive a single pending job")
        var result: Result<LegacyRunnerJob, Error>?
        LegacyRunnerLink.receive(LegacyRunnerJob.self, over: connection, limit: LegacyRunnerLink.maxJobSize) {
            result = $0
            received.fulfill()
        }
        guard await XCTWaiter.fulfillment(of: [received], timeout: 8) == .completed, let result else { return nil }
        // Opening the runner directly when no job is armed is harmless.
        if case .failure(let error as NWError) = result, error == .posix(.ECONNREFUSED) { return nil }
        return try result.get()
    }

    @MainActor
    private func execute(_ job: LegacyRunnerJob) throws -> LegacyRunnerResult {
        guard job.isValid else { throw JobError.invalidJob }
        let app = XCUIApplication(bundleIdentifier: job.target)
        if app.state == .notRunning { app.launch() } else { app.activate() }
        guard app.wait(for: .runningForeground, timeout: 7) else { throw JobError.targetNotForeground }
        let automation = RunnerAutomation(app: app)
        switch job.action {
        case .screenshot:
            break
        case .tap:
            let frame = try automation.capture()
            try automation.tap(pixel: point(job.x, job.y, in: frame), in: frame)
        case .swipe:
            let frame = try automation.capture()
            try automation.swipe(from: point(job.x, job.y, in: frame), to: point(job.endX, job.endY, in: frame), in: frame)
        }
        return LegacyRunnerResult(png: try automation.capture().png, error: nil)
    }

    private func point(_ x: Double, _ y: Double, in frame: RunnerScreenFrame) -> CGPoint {
        CGPoint(x: x * frame.pixelSize.width, y: y * frame.pixelSize.height)
    }

    enum JobError: LocalizedError {
        case invalidJob, targetNotForeground, resultTimedOut

        var errorDescription: String? {
            switch self {
            case .invalidJob: return "Invalid automation job."
            case .targetNotForeground: return "The target app did not reach the foreground. Check that it is installed and the phone is unlocked."
            case .resultTimedOut: return "TouchSynthesis did not receive the result in time."
            }
        }
    }
}
