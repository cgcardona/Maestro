import Foundation
import AsyncHTTPClient
import NIOCore

class OllamaAPI {
    static let shared = OllamaAPI()
    
    private let httpClient: HTTPClient
    private let baseURL = "http://localhost:11434"
    private let model: String
    
    private init() {
        self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        
        // Default to llama3.2:3b, but can be configured
        self.model = ProcessInfo.processInfo.environment["OLLAMA_MODEL"] ?? "llama3.2:3b"
        
        print("🦙 OllamaAPI initialized with model: \(model)")
    }
    
    deinit {
        try? httpClient.syncShutdown()
    }
    
    func complete(prompt: String, model: String? = nil) async throws -> String {
        let selectedModel = model ?? self.model
        let requestBody = OllamaRequest(
            model: selectedModel,
            prompt: prompt,
            stream: false,
            options: OllamaOptions(
                temperature: 0.7,
                top_p: 0.9,
                max_tokens: 4000
            )
        )
        
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(requestBody)
        
        var request = HTTPClientRequest(url: "\(baseURL)/api/generate")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .bytes(requestData)
        
        print("🦙 Sending request to Ollama...")
        
        let response = try await httpClient.execute(request, timeout: .seconds(120))
        
        guard response.status == .ok else {
            throw OllamaError.httpError(response.status.code)
        }
        
        let responseData = try await response.body.collect(upTo: 10 * 1024 * 1024) // 10MB limit
        
        let decoder = JSONDecoder()
        let ollamaResponse = try decoder.decode(OllamaResponse.self, from: responseData)
        
        print("✅ Received response from Ollama (\(ollamaResponse.response.count) chars)")
        
        return ollamaResponse.response
    }
    
    func isAvailable() async -> Bool {
        do {
            var request = HTTPClientRequest(url: "\(baseURL)/api/tags")
            request.method = .GET
            
            let response = try await httpClient.execute(request, timeout: .seconds(5))
            return response.status == .ok
        } catch {
            return false
        }
    }
    
    func listModels() async throws -> [String] {
        var request = HTTPClientRequest(url: "\(baseURL)/api/tags")
        request.method = .GET
        
        let response = try await httpClient.execute(request, timeout: .seconds(10))
        
        guard response.status == .ok else {
            throw OllamaError.httpError(response.status.code)
        }
        
        let responseData = try await response.body.collect(upTo: 1024 * 1024)
        
        let decoder = JSONDecoder()
        let tagsResponse = try decoder.decode(OllamaTagsResponse.self, from: responseData)
        
        return tagsResponse.models.map { $0.name }
    }
}

// MARK: - Request/Response Models

struct OllamaRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let options: OllamaOptions?
}

struct OllamaOptions: Codable {
    let temperature: Double?
    let top_p: Double?
    let max_tokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case temperature
        case top_p
        case max_tokens = "num_predict"
    }
}

struct OllamaResponse: Codable {
    let model: String
    let response: String
    let done: Bool
    let context: [Int]?
    let total_duration: Int?
    let load_duration: Int?
    let prompt_eval_count: Int?
    let prompt_eval_duration: Int?
    let eval_count: Int?
    let eval_duration: Int?
}

struct OllamaTagsResponse: Codable {
    let models: [OllamaModel]
}

struct OllamaModel: Codable {
    let name: String
    let size: Int
    let digest: String
    let modified_at: String
}

enum OllamaError: Error {
    case httpError(UInt)
    case invalidResponse
    case modelNotFound(String)
    
    var localizedDescription: String {
        switch self {
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .invalidResponse:
            return "Invalid response from Ollama"
        case .modelNotFound(let model):
            return "Model not found: \(model)"
        }
    }
} 