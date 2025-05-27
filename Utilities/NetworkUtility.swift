// Write testable code with dependency injection where appropriate
class NetworkUtility {
    // Add inline documentation for public methods
    /**
     Makes a network request and returns the response as JSON data.
     
     - Parameter url: The URL to make the request to.
     - Returns: A JSON object containing the response data.
     */
    func fetchJSON(_ url: String) -> Any? {
        if let url = URL(string: url) {
            var json: Any?
            
            // Use a dependency injection for the network request to allow for mocking and testing
            NetworkRequestManager().requestJSON(url, completionHandler: { (responseObject, error) in
                if let responseObject = responseObject as? [String: Any] {
                    json = responseObject["data"]
                }
            })
            
            return json
        } else {
            return nil
        }
    }
}