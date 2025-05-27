import Foundation

extension MathUtilities {
    /// Calculates the sum of two numbers.
    ///
    /// - Parameters:
    ///   - lhs: The first number.
    ///   - rhs: The second number.
    /// - Returns: The sum of `lhs` and `rhs`.
    static func + (lhs: Int, rhs: Int) -> Int {
        return add(lhs: lhs, rhs: rhs)
    }
    
    /// Calculates the difference between two numbers.
    ///
    /// - Parameters:
    ///   - lhs: The first number.
    ///   - rhs: The second number.
    /// - Returns: The difference between `lhs` and `rhs`.
    static func - (lhs: Int, rhs: Int) -> Int {
        return subtract(lhs: lhs, rhs: rhs)
    }
    
    /// Calculates the product of two numbers.
    ///
    /// - Parameters:
    ///   - lhs: The first number.
    ///   - rhs: The second number.
    /// - Returns: The product of `lhs` and `rhs`.
    static func * (lhs: Int, rhs: Int) -> Int {
        return multiply(lhs: lhs, rhs: rhs)
    }
    
    /// Calculates the quotient of two numbers.
    ///
    /// - Parameters:
    ///   - lhs: The first number.
    ///   - rhs: The second number.
    /// - Returns: The quotient of `lhs` and `rhs`.
    static func / (lhs: Int, rhs: Int) -> Double {
        return divide(lhs: lhs, rhs: rhs)
    }
}