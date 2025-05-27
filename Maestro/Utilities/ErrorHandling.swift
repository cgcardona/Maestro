// Write testable code with dependency injection where appropriate
import Foundation

enum MaestroError: Error {
    case invalidEmailAddress
}

protocol EmailValidatorProtocol {
    func isValid(email: String) -> Bool
}

class EmailValidator: EmailValidatorProtocol {
    var emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"

    /// Validates an email address using a regular expression
    /// - Parameter email: The email address to be validated
    func isValid(email: String) -> Bool {
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPredicate.evaluate(with: email)
    }
}