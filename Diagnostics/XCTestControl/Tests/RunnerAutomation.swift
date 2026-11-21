import ImageIO
import XCTest

struct RunnerScreenFrame {
    let png: Data
    let pixelSize: CGSize
    let appFrame: CGRect

    func pixelPoint(forScreenPoint point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - appFrame.minX) * pixelSize.width / appFrame.width,
                y: (point.y - appFrame.minY) * pixelSize.height / appFrame.height)
    }

    func normalizedOffset(forPixel point: CGPoint) throws -> CGVector {
        guard point.x.isFinite, point.y.isFinite,
              point.x >= 0, point.x < pixelSize.width,
              point.y >= 0, point.y < pixelSize.height else {
            throw RunnerAutomationError.pixelOutOfBounds
        }
        return CGVector(dx: point.x / pixelSize.width, dy: point.y / pixelSize.height)
    }
}

enum RunnerAutomationError: Error {
    case appNotForeground
    case invalidScreenshot
    case pixelOutOfBounds
    case appGeometryChanged
}

@MainActor
struct RunnerAutomation {
    let app: XCUIApplication

    func capture() throws -> RunnerScreenFrame {
        guard app.state == .runningForeground else { throw RunnerAutomationError.appNotForeground }
        let frame = app.frame
        let png = app.screenshot().pngRepresentation
        guard frame.width > 0, frame.height > 0, app.frame == frame,
              let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width > 0, image.height > 0 else {
            throw RunnerAutomationError.invalidScreenshot
        }
        return RunnerScreenFrame(png: png, pixelSize: CGSize(width: image.width, height: image.height), appFrame: frame)
    }

    func tap(pixel: CGPoint, in frame: RunnerScreenFrame) throws {
        try coordinate(pixel: pixel, in: frame).tap()
    }

    func swipe(from start: CGPoint, to end: CGPoint, in frame: RunnerScreenFrame) throws {
        let from = try coordinate(pixel: start, in: frame)
        let to = try coordinate(pixel: end, in: frame)
        from.press(forDuration: 0.05, thenDragTo: to)
    }

    private func coordinate(pixel: CGPoint, in frame: RunnerScreenFrame) throws -> XCUICoordinate {
        guard app.state == .runningForeground else { throw RunnerAutomationError.appNotForeground }
        guard app.frame == frame.appFrame else { throw RunnerAutomationError.appGeometryChanged }
        return app.coordinate(withNormalizedOffset: try frame.normalizedOffset(forPixel: pixel))
    }
}
