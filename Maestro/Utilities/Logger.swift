// Add inline documentation for public methods
import Foundation

class Logger {
    // Follow SOLID principles
    enum LogLevel: Int, CustomStringConvertible {
        case error = 0
        case warning = 1
        case info = 2

        var description: String {
            switch self {
            case .error: return "Error"
            case .warning: return "Warning"
            case .info: return "Info"
            }
        }
    }

    // Write testable code with dependency injection where appropriate
    private let logLevel: LogLevel

    init(logLevel: LogLevel = .error) {
        self.logLevel = logLevel
    }

    /// Prints a message to the console based on the current log level
    /// - Parameters:
    ///   - message: The message to be printed
    ///   - level: The log level of the message (defaults to .error)
    func print(message: String, level: LogLevel = .error) {
        guard level.rawValue <= self.logLevel.rawValue else { return }
        print("[Maestro] \(level.description): \(message)")
    }
}