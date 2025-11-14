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

    func testBugReportPayloadContainsTeam() throws {
        let report = BugReport(
            description: "Test",
            priority: "low",
            userActions: [],
            deviceInfo: DeviceInfo(),
            appInfo: AppInfo()
        )

        let service = BugReportAPIService(webhookURL: "https://example.com")
        let data = try service.makeEncodedPayload(for: report, gitLabCredentials: nil)

        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = json as? [String: Any],
              let reportObj = dict["report"] as? [String: Any],
              let team = reportObj["team"] as? String else {
            XCTFail("Malformed payload")
            return
        }

        XCTAssertEqual(team, "ios", "Payload report.team should be 'ios'")
    }

    func testBugReportServiceTimeoutsAreFiveMinutes() {
        let service = BugReportAPIService(webhookURL: "https://example.com")

        let req = service.testTimeoutIntervalForRequest
        let res = service.testTimeoutIntervalForResource

        XCTAssertEqual(req, 5 * 60, "Request timeout should be 5 minutes")
        XCTAssertEqual(res, 5 * 60, "Resource timeout should be 5 minutes")
    }

    func testRecordingConfirmationFallbackAddsRecording() throws {
        let manager = QCBugPluginManager()

        // Create temporary dummy recording file
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = tmpDir.appendingPathComponent("test_recording.mp4")
        try Data().write(to: fileURL)

        let expect = expectation(description: "confirmation fallback completes")

        manager.test_invokeShowRecordingConfirmationFallback(recordingURL: fileURL) { result in
            switch result {
            case .success(let url):
                XCTAssertEqual(url.path, fileURL.path)
                XCTAssertGreaterThanOrEqual(manager.test_getSessionMediaCount(), 1)
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
            expect.fulfill()
        }

        waitForExpectations(timeout: 2)
    }
}
