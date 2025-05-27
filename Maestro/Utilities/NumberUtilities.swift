// Add inline documentation for public methods
import Foundation

struct NumberUtilities {
    // Follow SOLID principles
    struct CurrencyFormatter {
        static let currencyFormatter = NumberFormatter()

        /// Formats a number to the current locale's currency format
        /// - Parameter number: The number to be formatted
        func format(number: NSNumber) -> String {
            return currencyFormatter.string(from: number)!
        }
    }
}