import Foundation

struct InfrastructureAgent: SpecialistAgent {
    let role = "Infrastructure Specialist"
    let skills = ["infrastructure analysis", "cost modeling", "performance evaluation", "vendor assessment", "scalability planning", "sla analysis", "cloud architecture", "service comparison"]
    
    let qualityStandards: [AgentTask.QualityLevel: String] = [
        .standard: "Basic infrastructure analysis with cost comparison and basic performance metrics",
        .high: "Comprehensive infrastructure assessment with detailed cost modeling, performance benchmarks, and scalability planning",
        .critical: "Enterprise-grade infrastructure strategy with multi-vendor analysis, disaster recovery planning, and compliance assessment"
    ]
    
    func execute(task: AgentTask, outputDirectoryPath: String) async throws -> TaskResult {
        print("🏗️ \(role) starting task: \(task.title)")
        
        let prompt = createInfrastructurePrompt(for: task)
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
    
    private func createInfrastructurePrompt(for task: AgentTask) -> String {
        let basePrompt = createPrompt(for: task)
        
        return """
        \(basePrompt)
        
        ## Infrastructure Analysis Guidelines:
        
        You are a senior infrastructure architect evaluating solutions for TellUrStori's production deployment. Please provide:
        
        1. **Service Comparison**: Detailed analysis of multiple providers with feature matrices
        2. **Cost Modeling**: Comprehensive pricing analysis with usage scenarios and projections
        3. **Performance Assessment**: Latency, throughput, reliability, and global availability analysis
        4. **Scalability Planning**: Growth scenarios and capacity planning
        5. **Risk Assessment**: Vendor lock-in, service reliability, and mitigation strategies
        6. **Implementation Strategy**: Migration planning and deployment recommendations
        
        ## TellUrStori Infrastructure Context:
        - Native macOS storytelling application with growing user base
        - Multimedia content storage and delivery requirements
        - Global user distribution requiring CDN capabilities
        - Cost-sensitive startup with need for scalable pricing
        - Integration with TUS token payment system
        - High availability and performance requirements
        
        ## Evaluation Criteria:
        - Cost effectiveness and transparent pricing
        - Performance and global availability
        - API quality and integration complexity
        - Scalability and growth accommodation
        - Security and compliance features
        - Community support and documentation quality
        
        ## Output Format:
        
        Please structure your infrastructure analysis as:
        
        # Infrastructure Analysis: [Task Title]
        
        ## Executive Summary
        [Key findings and recommendations]
        
        ## Provider Comparison Matrix
        [Detailed feature and capability comparison]
        
        ## Cost Analysis
        [Pricing models with usage scenarios and projections]
        
        | Provider | Pricing Model | Cost at 1K users | Cost at 10K users | Cost at 100K users |
        |----------|---------------|-------------------|-------------------|---------------------|
        | Provider A | Details | $X/month | $Y/month | $Z/month |
        
        ## Performance Benchmarks
        [Latency, throughput, and reliability metrics]
        
        ## Scalability Assessment
        [Growth scenarios and capacity planning]
        
        ## Integration Complexity
        [API quality, documentation, and implementation effort]
        
        ## Risk Analysis
        [Vendor risks and mitigation strategies]
        
        ## Recommended Strategy
        [Primary and backup provider recommendations with rationale]
        
        ## Implementation Roadmap
        [Migration planning and deployment phases]
        
        ## Monitoring and Optimization
        [Performance monitoring and cost optimization strategies]
        
        Provide data-driven infrastructure recommendations that balance cost, performance, and risk for a growing platform.
        """
    }
} 