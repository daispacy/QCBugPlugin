import XCTest
@testable import QCBugPlugin

final class QCBugPluginTests: XCTestCase {
    
    func testExample() {
        // This is an example test
        XCTAssertTrue(true)
    }
    
    func testFrameworkVersion() {
        XCTAssertEqual(QCBugPlugin.version, "1.0.0")
    }
}
