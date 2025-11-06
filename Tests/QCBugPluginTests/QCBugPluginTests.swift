import XCTest
import UIKit
@testable import QCBugPlugin

final class QCBugPluginTests: XCTestCase {
    func testConfigurationDoesNotCrash() {
        let config = QCBugPluginConfig(webhookURL: "https://example.com")
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()

        QCBugPlugin.configure(using: window, configuration: config)

        XCTAssertTrue(true, "Configuration should succeed without crashing")
    }
}
