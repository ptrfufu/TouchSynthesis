import XCTest

final class RunnerHandshakeTests: XCTestCase {
    @MainActor
    func testFixtureTapSwipeAndScreenshot() {
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
        tap.tap()
        XCTAssertEqual(app.staticTexts["fixture.pending"].label, "点按 通过 · 滑动 待测")

        let swipe = app.descendants(matching: .any)["fixture.swipe"].firstMatch
        guard swipe.waitForExistence(timeout: 5) else {
            XCTFail("Missing swipe target")
            return
        }
        let start = swipe.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        let end = swipe.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(app.staticTexts["fixture.passed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.screenshot().pngRepresentation.isEmpty)
    }
}
