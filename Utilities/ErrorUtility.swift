// Use proper Swift naming conventions
class ErrorUtility {
    // Add inline documentation for public methods
    /**
     Converts an error object to a string representation.
     
     - Parameter error: The error object to convert.
     - Returns: A string representation of the error.
     */
    func toString(_ error: Error) -> String {
        return "\(error)"
    }
}