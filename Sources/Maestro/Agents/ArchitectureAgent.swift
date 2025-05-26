import Foundation

struct ArchitectureAgent: SpecialistAgent {
    let role = "System Architect"
    let skills = ["system architecture", "technical documentation", "integration design", "solution design", "api design", "data modeling", "diagramming", "software design patterns", "smart contract architecture", "payment systems design", "security architecture"]
    
    let qualityStandards: [AgentTask.QualityLevel: String] = [
        .standard: "Clear architectural overview with key components and basic diagrams",
        .high: "Comprehensive architecture design with detailed diagrams, data models, API specifications, and integration patterns",
        .critical: "Enterprise-grade architecture with full documentation, scalability analysis, security design, and future-proofing"
    ]
    
    func execute(task: AgentTask, outputDirectoryPath: String) async throws -> TaskResult {
        print("🏛️ \(role) starting task: \(task.title)")
        
        let prompt = createArchitecturePrompt(for: task)
        let responseContent = try await AnthropicAPI.shared.complete(prompt: prompt)

        let sanitizedTitle = task.title.replacingOccurrences(of: "[^a-zA-Z0-9_-\\.]", with: "_", options: .regularExpression)
        let outputFileName = "\(sanitizedTitle).md"
        let outputFilePath = URL(fileURLWithPath: outputDirectoryPath).appendingPathComponent(outputFileName).path
        
        do {
            try responseContent.write(toFile: outputFilePath, atomically: true, encoding: .utf8)
            print("📄 Saved \(role) output to: \(outputFilePath)")
        } catch {
            print("🚨 Error saving \(role) output file: \(error.localizedDescription)")
        }
        
        print("✅ \(role) completed task: \(task.title)")
        
        return TaskResult(
            taskId: task.id,
            content: responseContent,
            status: .completed,
            notes: "Completed by \(role). Output saved to \(outputFilePath)",
            generatedFiles: [outputFilePath]
        )
    }
    
    private func createArchitecturePrompt(for task: AgentTask) -> String {
        let basePrompt = createPrompt(for: task)
        
        return """
        \(basePrompt)
        
        ## System Architecture Guidelines:
        
        You are a senior system architect designing solutions for TellUrStori. Please provide:
        
        1.  **Architecture Design**: Clear diagrams (component, sequence, deployment) and specifications.
        2.  **API Design**: RESTful API endpoints, request/response schemas, authentication.
        3.  **Data Modeling**: Database schemas, data flow diagrams, entity-relationship models.
        4.  **Integration Patterns**: How different services and components connect and communicate.
        5.  **Scalability & Performance**: Design for growth, load balancing, caching strategies.
        6.  **Security Design**: Authentication, authorization, data protection, threat modeling.
        7.  **Technical Documentation**: Comprehensive architecture documents and design rationale.
        
        ## TellUrStori Technical Context:
        -   Native macOS application (Swift/SwiftUI, MVVM).
        -   Backend services for user data, content management.
        -   Integration with third-party APIs (e.g., AvaCloud, IPFS).
        -   Focus on multimedia content, real-time collaboration (potential future).
        -   Need for robust, scalable, and secure architecture.
        
        ## Output Format:
        
        Please structure your architectural design as:
        
        # Architecture Design: [Task Title]
        
        ## 1. Executive Summary
        [Brief overview of the proposed architecture and key decisions.]
        
        ## 2. Requirements Addressed
        [How this design meets the task goals and acceptance criteria.]
        
        ## 3. System Architecture
        [High-level overview, component diagrams, description of modules.]
        
        ### 3.1. Component Diagram
        ```mermaid
        graph TD
            A[Client App] --> B(API Gateway)
            B --> C{Service A}
            B --> D{Service B}
        ```
        
        ### 3.2. Data Model
        [ERDs, schema definitions.]
        
        ## 4. API Design (if applicable)
        [Endpoint definitions, request/response examples.]
        
        ### GET /resource/{id}
        -   Description: ...
        -   Response: `{"id": "uuid", "name": "string"}`
        
        ## 5. Integration Strategy
        [How this system integrates with existing or new components.]
        
        ## 6. Scalability and Performance Considerations
        [Design choices for handling load and growth.]
        
        ## 7. Security Considerations
        [Authentication, authorization, data privacy, etc.]
        
        ## 8. Deployment Strategy
        [Considerations for deploying this architecture.]
        
        ## 9. Design Rationale & Trade-offs
        [Explanation of key design choices and alternatives considered.]
        
        Provide a clear, detailed, and actionable architecture design that can be readily implemented.
        """
    }
} 