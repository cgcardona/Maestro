import XCTest
@testable import MathUtils

class MathUtilitiesTests: XCTestCase {
    
    func testAdd() {
        let result = MathUtilities.add(lhs: 2, rhs: 3)
        XCTAssertEqual(result, 5)
    }
    
    func testSubtract() {
        let result = MathUtilities.subtract(lhs: 6, rhs: 2)
        XCTAssertEqual(result, 4)
    }
    
    func testMultiply() {
        let result = MathUtilities.multiply(lhs: 3, rhs: 4)
        XCTAssertEqual(result, 12)
    }
    
    func testDivide() {
        let result = MathUtilities.divide(lhs: 12, rhs: 4)
        XCTAssertEqual(result, 3)
    }
    
    func testGcd() {
        let result = MathUtilities.gcd(lhs: 10, rhs: 15)
        XCTAssertEqual(result, 5)
    }
    
    func testLcm() {
        let result = MathUtilities.lcm(lhs: 12, rhs: 15)
        XCTAssertEqual(result, 60)
    }
}