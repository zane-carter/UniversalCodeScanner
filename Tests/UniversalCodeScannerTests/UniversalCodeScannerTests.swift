import XCTest
@testable import UniversalCodeScanner

final class UniversalCodeScannerTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(UniversalCodeScanner().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
