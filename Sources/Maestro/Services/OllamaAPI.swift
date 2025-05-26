import Foundation
import AsyncHTTPClient
import NIOCore

// Simple AsyncSemaphore implementation
actor AsyncSemaphore {
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(count: Int) {
        self.count = count
    }

    func wait() async {
        if count > 0 {
            count -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if waiters.isEmpty {
            count += 1
        } else {
            let waiter = waiters.removeFirst()
            waiter.resume()
        }
    }
}

class OllamaAPI {
    static let shared = OllamaAPI()
    
    private let httpClient: HTTPClient
    private let baseURL: String
    private let model: String
    private let ollamaSemaphore: AsyncSemaphore
    
    private init() {
        self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        
        self.baseURL = ProcessInfo.processInfo.environment["OLLAMA_API_BASE_URL"] ?? "http://localhost:11434"
        self.model = ProcessInfo.processInfo.environment["OLLAMA_DEFAULT_MODEL"] ?? "llama3.2:3b"
        self.ollamaSemaphore = AsyncSemaphore(count: 3)
        
        print("🦙 OllamaAPI initialized with model: \(model) at base URL: \(baseURL)")
    }
    
    deinit {
        try? httpClient.syncShutdown()
    }
    
    func complete(prompt: String, model: String? = nil) async throws -> String {
        await ollamaSemaphore.wait()
        defer { Task { await ollamaSemaphore.signal() } }

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
        
        print("🦙 Sending request to Ollama for model \(selectedModel)...")
        
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
        await ollamaSemaphore.wait()
        defer { Task { await ollamaSemaphore.signal() } }
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
        await ollamaSemaphore.wait()
        defer { Task { await ollamaSemaphore.signal() } }
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