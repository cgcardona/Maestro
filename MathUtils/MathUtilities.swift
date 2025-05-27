import Foundation

// MARK: - Math Utility Functions

/// Calculates the sum of two numbers.
///
/// - Parameters:
///   - lhs: The first number.
///   - rhs: The second number.
/// - Returns: The sum of `lhs` and `rhs`.
func add(lhs: Int, rhs: Int) -> Int {
    return lhs + rhs
}

/// Calculates the difference between two numbers.
///
/// - Parameters:
///   - lhs: The first number.
///   - rhs: The second number.
/// - Returns: The difference between `lhs` and `rhs`.
func subtract(lhs: Int, rhs: Int) -> Int {
    return lhs - rhs
}

/// Calculates the product of two numbers.
///
/// - Parameters:
///   - lhs: The first number.
///   - rhs: The second number.
/// - Returns: The product of `lhs` and `rhs`.
func multiply(lhs: Int, rhs: Int) -> Int {
    return lhs * rhs
}

/// Calculates the quotient of two numbers.
///
/// - Parameters:
///   - lhs: The first number.
///   - rhs: The second number.
/// - Returns: The quotient of `lhs` and `rhs`.
func divide(lhs: Int, rhs: Int) -> Double {
    return Double(lhs) / Double(rhs)
}

// MARK: - Internal Utility Functions

/// Calculates the greatest common divisor of two numbers.
///
/// - Parameters:
///   - lhs: The first number.
///   - rhs: The second number.
/// - Returns: The greatest common divisor of `lhs` and `rhs`.
func gcd(lhs: Int, rhs: Int) -> Int {
    return lhs.gcd(with: rhs)
}

/// Calculates the least common multiple of two numbers.
///
/// - Parameters:
///   - lhs: The first number.
///   - rhs: The second number.
/// - Returns: The least common multiple of `lhs` and `rhs`.
func lcm(lhs: Int, rhs: Int) -> Int {
    return (lhs / gcd(lhs: lhs, rhs: rhs)) * rhs
}