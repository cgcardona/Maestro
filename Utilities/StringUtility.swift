// Use proper Swift naming conventions
class StringUtility {
    // Include comprehensive error handling
    func isValidEmail(_ email: String) -> Bool {
        do {
            try NSRegularExpression(pattern: "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$", options: .caseInsensitive).firstMatch(in: email, options: [], range: NSMakeRange(0, email.count)) != nil
        } catch {
            return false
        }
    }
}