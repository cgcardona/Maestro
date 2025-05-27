import Foundation

/// A class responsible for managing the application's configuration settings.
class ConfigurationManager {
    /// The singleton instance of the `ConfigurationManager`.
    static let shared = ConfigurationManager()
    
    /// The path to the configuration file on disk.
    private let configFilePath: URL
    
    /// Initializes a new instance of the `ConfigurationManager` with the given configuration file path.
    /// - Parameter configFilePath: The path to the configuration file on disk.
    init(configFilePath: URL) {
        self.configFilePath = configFilePath
    }
    
    /// Loads the configuration settings from the specified file path and returns them as a dictionary.
    /// - Returns: A dictionary containing the loaded configuration settings.
    func loadConfiguration() throws -> [String: Any] {
        do {
            let data = try Data(contentsOf: configFilePath)
            return try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String: Any]
        } catch {
            throw ConfigurationManagerError.failedToLoadConfiguration(underlyingError: error)
        }
    }
    
    /// Saves the specified configuration settings to disk at the given file path.
    /// - Parameters:
    ///   - configuration: The dictionary containing the configuration settings to save.
    ///   - configFilePath: The path to the configuration file on disk.
    func saveConfiguration(configuration: [String: Any], configFilePath: URL) throws {
        do {
            let data = try JSONSerialization.data(withJSONObject: configuration, options: .prettyPrinted)
            try data.write(to: configFilePath)
        } catch {
            throw ConfigurationManagerError.failedToSaveConfiguration(underlyingError: error)
        }
    }
    
    /// Sets the specified configuration setting to the given value.
    /// - Parameters:
    ///   - key: The name of the configuration setting to set.
    ///   - value: The value to set for the configuration setting.
    func setConfiguration(key: String, value: Any) {
        var configuration = try! loadConfiguration()
        configuration[key] = value
        saveConfiguration(configuration: configuration, configFilePath: configFilePath)
    }
    
    /// Gets the specified configuration setting.
    /// - Parameter key: The name of the configuration setting to get.
    /// - Returns: The value of the requested configuration setting.
    func getConfiguration(key: String) -> Any? {
        let configuration = try! loadConfiguration()
        return configuration[key]
    }
}