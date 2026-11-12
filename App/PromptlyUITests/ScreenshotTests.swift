import XCTest

/// Takes the App Store screenshots. Each test launches Pop In in screenshot mode (demo meetings, no calendar, no
/// alarms) and saves one picture as a test attachment; the Screenshots workflow exports them.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
        } else {
            XCUIDevice.shared.orientation = .portrait
        }
    }

    private func launch(_ scene: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshots", "-scene", scene]
        app.launch()
        return app
    }

    private func snap(_ name: String, after seconds: TimeInterval = 2.5) {
        Thread.sleep(forTimeInterval: seconds)
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "\(device)-\(name)"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func test1Home() { _ = launch("home"); snap("1-home") }

    func test2Now() { _ = launch("now"); snap("2-now") }

    func test3Late() { _ = launch("late"); snap("3-late", after: 4) }

    func test4Unicorn() { _ = launch("unicorn"); snap("4-unicorn") }

    func test5Settings() { _ = launch("settings"); snap("5-settings", after: 3) }

    func test8Fortune() { _ = launch("fortune"); snap("8-fortune") }

    /// For App Store Connect's in-app purchase review screenshot.
    func test7Pro() { _ = launch("pro"); snap("7-pro", after: 4) }

    func test6Pop() {
        let app = launch("pop")
        Thread.sleep(forTimeInterval: 2.5)
        let bubble = app.descendants(matching: .any)["Pop the bubble to join Design review"].firstMatch
        if bubble.waitForExistence(timeout: 5) {
            bubble.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72)).tap()
        }
        snap("6-pop", after: 0.3)
    }
}
