import Foundation
import AsyncHTTPClient
import NIOHTTP1

class AnthropicAPI {
    static let shared = AnthropicAPI()
    private let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
    private let apiKey: String
    private let mockMode: Bool
    
    private init() {
        // Load API key from environment
        self.apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        self.mockMode = apiKey.isEmpty
        
        // No mock mode logging here; it's handled in the complete() method
        // to provide accurate context based on Ollama's availability.
    }
    
    func complete(prompt: String, model: String = "claude-3-sonnet-20240229") async throws -> String {
        if mockMode {
            // Try Ollama first
            if await OllamaAPI.shared.isAvailable() {
                print("🦙 Anthropic API key not found, but Ollama is available. Using Ollama for local inference.")
                return try await OllamaAPI.shared.complete(prompt: prompt)
            } else {
                print("🧪 Anthropic API key not found AND Ollama not available. Using Anthropic mock response.")
                return generateMockResponse(for: prompt)
            }
        }
        
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4000,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = HTTPClientRequest(url: "https://api.anthropic.com/v1/messages")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "x-api-key", value: apiKey)
        request.headers.add(name: "anthropic-version", value: "2023-06-01")
        request.body = .bytes(jsonData)
        
        let response = try await httpClient.execute(request, timeout: .seconds(60))
        let responseData = try await response.body.collect(upTo: 1024 * 1024) // 1MB limit
        
        guard response.status == .ok else {
            let errorData = String(buffer: responseData)
            throw APIError.requestFailed(response.status, errorData)
        }
        
        let jsonResponse = try JSONSerialization.jsonObject(with: Data(buffer: responseData)) as? [String: Any]
        
        if let content = jsonResponse?["content"] as? [[String: Any]],
           let firstContent = content.first,
           let text = firstContent["text"] as? String {
            return text
        }
        
        throw APIError.invalidResponse
    }
    
    private func generateMockResponse(for prompt: String) -> String {
        // Simulate a delay
        Thread.sleep(forTimeInterval: 1.0)
        
        return """
        # TellUrStori Competitive Analysis Report
        
        ## Executive Summary
        Based on my analysis of the storytelling platform market, TellUrStori operates in a competitive but differentiated space with significant opportunities for growth.
        
        ## Competitor Analysis
        
        ### 1. StoryMapJS (Northwestern University)
        - **Strengths**: Academic backing, timeline-based storytelling, free to use
        - **Weaknesses**: Limited multimedia support, basic UI/UX
        - **Market Position**: Educational/journalistic focus
        
        ### 2. Shorthand (Social)
        - **Strengths**: Professional publishing tools, multimedia integration
        - **Weaknesses**: Expensive, complex for casual users
        - **Market Position**: Enterprise/media companies
        
        ### 3. Adobe Spark (Now Adobe Express)
        - **Strengths**: Brand recognition, design templates, integration with Creative Suite
        - **Weaknesses**: Generic templates, limited storytelling-specific features
        - **Market Position**: General content creation
        
        ### 4. Twine (Interactive Fiction)
        - **Strengths**: Strong community, open-source, branching narratives
        - **Weaknesses**: Text-focused, technical learning curve
        - **Market Position**: Interactive fiction/gaming
        
        ### 5. Medium
        - **Strengths**: Large audience, built-in distribution, monetization
        - **Weaknesses**: Limited multimedia, algorithm-dependent reach
        - **Market Position**: Professional writing/blogging
        
        ## Feature Gap Analysis
        
        ### High-Impact Opportunities:
        1. **AI-Assisted Story Structure**: None of the competitors offer intelligent story arc suggestions
        2. **Collaborative Storytelling**: Limited real-time collaboration features across platforms
        3. **Cross-Platform Publishing**: Seamless distribution to multiple channels
        4. **Analytics & Engagement Tracking**: Story performance insights for creators
        
        ### Medium-Impact Opportunities:
        1. **Voice Integration**: Audio storytelling capabilities
        2. **AR/VR Elements**: Immersive story experiences
        3. **Community Features**: Story discovery and creator networking
        
        ## Unique Value Proposition
        
        **TellUrStori's Differentiation:**
        - Focus on narrative structure and storytelling craft
        - AI-powered story enhancement tools
        - Community-driven discovery and feedback
        - Multi-format publishing (web, mobile, print, audio)
        
        ## Strategic Recommendations
        
        ### Immediate (0-3 months):
        1. Emphasize AI story structure assistance in marketing
        2. Build partnerships with writing communities and educators
        3. Develop case studies showcasing unique storytelling outcomes
        
        ### Short-term (3-6 months):
        1. Implement collaborative editing features
        2. Create story template library based on successful narratives
        3. Launch creator monetization program
        
        ### Long-term (6-12 months):
        1. Develop mobile-first creation tools
        2. Build API for third-party integrations
        3. Explore acquisition opportunities in adjacent markets
        
        ## Market Positioning Strategy
        
        **Primary Message**: "The only platform that understands story structure as well as you do"
        
        **Target Segments**:
        1. **Primary**: Independent creators and small content teams
        2. **Secondary**: Educational institutions teaching narrative
        3. **Tertiary**: Marketing teams creating brand stories
        
        ## Competitive Advantages to Leverage
        
        1. **Story-First Approach**: Unlike general content tools, focus specifically on narrative craft
        2. **AI Integration**: Smart suggestions for plot development, character arcs, pacing
        3. **Community Ecosystem**: Built-in audience and feedback mechanisms
        4. **Multi-Format Output**: One story, multiple distribution channels
        
        This analysis positions TellUrStori as a specialized tool in a market of generalists, with clear opportunities to capture market share through focused innovation in storytelling technology.
        """
    }
    
    enum APIError: Error {
        case missingAPIKey
        case requestFailed(HTTPResponseStatus, String)
        case invalidResponse
        
        var localizedDescription: String {
            switch self {
            case .missingAPIKey:
                return "ANTHROPIC_API_KEY environment variable not set"
            case .requestFailed(let status, let error):
                return "API request failed with status \(status): \(error)"
            case .invalidResponse:
                return "Invalid response format from API"
            }
        }
    }
} 