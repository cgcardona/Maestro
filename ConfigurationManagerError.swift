import Foundation

/// An enum representing the possible errors that can occur when working with the `ConfigurationManager`.
enum ConfigurationManagerError: Error {
    case failedToLoadConfiguration(underlyingError: Error)
    case failedToSaveConfiguration(underlyingError: Error)
}