import Foundation

let configFilePath = URL(fileURLWithPath: "path/to/config.json")

do {
    let configurationManager = try ConfigurationManager(configFilePath: configFilePath)
    
    // Set a new configuration setting
    configurationManager.setConfiguration(key: "mySetting", value: 123)
    
    // Get the current value of an existing configuration setting
    let myValue = configurationManager.getConfiguration(key: "mySetting")
} catch {
    print("Failed to load or save configuration: \(error)")
}