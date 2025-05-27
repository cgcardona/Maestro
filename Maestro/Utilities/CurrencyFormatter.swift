// Use proper Swift naming conventions
import Foundation

struct CurrencyFormatter {
    // Include comprehensive error handling
    static let currencyFormatter = NumberFormatter()

    /// Formats a number to the current locale's currency format
    /// - Parameter number: The number to be formatted
    func format(number: NSNumber) -> String {
        return currencyFormatter.string(from: number)!
    }
}