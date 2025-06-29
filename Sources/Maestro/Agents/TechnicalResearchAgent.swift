import Foundation

struct TechnicalResearchAgent: SpecialistAgent {
    let role = "Technical Research Specialist"
    let skills = ["protocol analysis", "technical research", "integration planning", "api analysis", "system architecture", "technology evaluation", "feasibility analysis", "technical documentation"]
    
    let qualityStandards: [AgentTask.QualityLevel: String] = [
        .standard: "Basic technical research with key findings and implementation overview",
        .high: "Comprehensive technical analysis with detailed integration plans, code examples, and risk assessment",
        .critical: "Enterprise-grade technical research with proof-of-concept implementation, security analysis, and production readiness assessment"
    ]
    
    func execute(task: AgentTask, outputDirectoryPath: String) async throws -> TaskResult {
        print("🔬 \(role) starting task: \(task.title)")
        
        let prompt = createTechnicalResearchPrompt(for: task)
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
    
    private func createTechnicalResearchPrompt(for task: AgentTask) -> String {
        let basePrompt = createPrompt(for: task)
        
        return """
        \(basePrompt)
        
        ## Technical Research Guidelines:
        
        You are a senior technical researcher analyzing technologies for TellUrStori integration. Please provide:
        
        1. **Technical Specification Analysis**: Deep dive into protocols, APIs, and architectures
        2. **Integration Assessment**: Feasibility, complexity, and implementation approaches
        3. **Code Examples**: Practical implementation samples and proof-of-concepts
        4. **Performance Analysis**: Scalability, latency, and resource requirements
        5. **Security Evaluation**: Security implications and best practices
        6. **Ecosystem Analysis**: Available tools, libraries, and community support
        
        ## TellUrStori Technical Context:
        - Native macOS application built with Swift/SwiftUI
        - MVVM architecture with modern Swift patterns
        - Integration with external APIs and services
        - Focus on performance and user experience
        - Security and privacy considerations
        - Scalability for growing user base
        
        ## Research Methodology:
        - Primary source documentation analysis
        - Community examples and best practices
        - Performance benchmarking and testing
        - Security and compliance assessment
        - Implementation complexity evaluation
        - Long-term maintenance considerations
        
        ## Output Format:
        
        Please structure your technical research as:
        
        # Technical Research: [Task Title]
        
        ## Executive Summary
        [Key findings and recommendations]
        
        ## Technology Overview
        [Detailed technical specification and capabilities]
        
        ## Integration Analysis
        [How it fits with TellUrStori architecture]
        
        ## Implementation Approach
        [Step-by-step integration strategy]
        
        ```swift
        // Include relevant Swift code examples
        ```
        
        ## Performance Considerations
        [Scalability, latency, and resource analysis]
        
        ## Security Assessment
        [Security implications and best practices]
        
        ## Ecosystem Evaluation
        [Available tools, libraries, and community support]
        
        ## Risk Analysis
        [Technical risks and mitigation strategies]
        
        ## Implementation Roadmap
        [Phased approach with milestones and dependencies]
        
        ## Resource Requirements
        [Development effort, infrastructure, and ongoing maintenance]
        
        ## Alternative Solutions
        [Comparison with other approaches and technologies]
        
        Provide actionable technical insights with practical implementation guidance and realistic assessments.
        """
    }
} 