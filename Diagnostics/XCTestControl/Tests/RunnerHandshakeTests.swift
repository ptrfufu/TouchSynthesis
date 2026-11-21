import XCTest

final class RunnerHandshakeTests: XCTestCase {
    @MainActor
    func testFixtureTapSwipeAndScreenshot() throws {
        let app = XCUIApplication(bundleIdentifier: "com.touchsynthesis.diagnostics.gesturefixture")
        app.launchArguments = ["--reset-gesture-result"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertEqual(app.staticTexts["fixture.pending"].label, "点按 待测 · 滑动 待测")

        let tap = app.buttons["fixture.tap"]
        guard tap.waitForExistence(timeout: 10) else {
            XCTFail("Missing tap target")
            return
        }
        let automation = RunnerAutomation(app: app)
        let originalFrame = try automation.capture()
        let center = CGPoint(x: tap.frame.midX, y: tap.frame.midY)
        try automation.tap(pixel: originalFrame.pixelPoint(forScreenPoint: center), in: originalFrame)
        XCTAssertEqual(app.staticTexts["fixture.pending"].label, "点按 通过 · 滑动 待测")

        let swipe = app.descendants(matching: .any)["fixture.swipe"].firstMatch
        guard swipe.waitForExistence(timeout: 5) else {
            XCTFail("Missing swipe target")
            return
        }
        let frame = swipe.frame
        let gestureFrame = try automation.capture()
        let start = CGPoint(x: frame.midX, y: frame.minY + 0.8 * frame.height)
        let end = CGPoint(x: frame.midX, y: frame.minY + 0.2 * frame.height)
        try automation.swipe(from: gestureFrame.pixelPoint(forScreenPoint: start),
                             to: gestureFrame.pixelPoint(forScreenPoint: end), in: gestureFrame)
        guard app.staticTexts["fixture.passed"].waitForExistence(timeout: 5) else {
            XCTFail("The fixture did not receive both gestures")
            return
        }
        let finalFrame = try automation.capture()
        XCTAssertFalse(finalFrame.png.isEmpty)
        app.launchArguments = ["--gesture-screenshot-verified"]
        app.launch()
        XCTAssertTrue(app.staticTexts["fixture.screenshot.verified"].waitForExistence(timeout: 5))
    }
}
