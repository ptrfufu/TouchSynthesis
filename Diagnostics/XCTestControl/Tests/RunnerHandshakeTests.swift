import XCTest

final class RunnerHandshakeTests: XCTestCase {
    @MainActor
    func testTouchSynthesisLaunchAndScreenshot() {
        let app = XCUIApplication(bundleIdentifier: "com.touchsynthesis.app.X7Z5P79VFB")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        let button = app.buttons.containing(.staticText, identifier: "Start UI Automation").firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertFalse(app.screenshot().pngRepresentation.isEmpty)
    }
}
