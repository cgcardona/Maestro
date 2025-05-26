import Foundation

struct TokenomicsAgent: SpecialistAgent {
    let role = "Tokenomics Specialist"
    let skills = ["tokenomics design", "economic modeling", "game theory", "financial analysis", "behavioral economics", "platform economics", "defi", "smart contracts", "token utility", "incentive design", "payment systems", "security analysis"]
    
    let qualityStandards: [AgentTask.QualityLevel: String] = [
        .standard: "Basic tokenomics framework with core utility mechanisms and simple economic model",
        .high: "Comprehensive tokenomics design with detailed economic modeling, incentive analysis, and sustainability planning",
        .critical: "Enterprise-grade tokenomics with advanced economic modeling, stress testing, audit-ready documentation, and regulatory compliance"
    ]
    
    func execute(task: AgentTask, outputDirectoryPath: String) async throws -> TaskResult {
        print("💰 \(role) starting task: \(task.title)")
        
        let prompt = createTokenomicsPrompt(for: task)
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
    
    private func createTokenomicsPrompt(for task: AgentTask) -> String {
        let basePrompt = createPrompt(for: task)
        
        return """
        \(basePrompt)
        
        ## Tokenomics Design Guidelines:
        
        You are a senior tokenomics designer working on TUS (TellUrStori) token for a storytelling platform. Please provide:
        
        1. **Token Utility Design**: Multiple use cases that create genuine value and demand
        2. **Economic Modeling**: Supply/demand dynamics, inflation/deflation mechanisms
        3. **Incentive Alignment**: Reward structures that promote desired behaviors
        4. **Sustainability Analysis**: Long-term viability and growth scenarios
        5. **Risk Assessment**: Economic risks and mitigation strategies
        6. **Implementation Roadmap**: Phased rollout with testing and validation
        
        ## TellUrStori Platform Context:
        - Native macOS storytelling application
        - Content creation and sharing platform
        - User-generated multimedia stories
        - Creator economy with monetization needs
        - IPFS storage integration for decentralized content
        - Community-driven platform with social features
        
        ## Token Design Principles:
        - Real utility beyond speculation
        - Sustainable economic model
        - Fair distribution and accessibility
        - Regulatory compliance considerations
        - User experience optimization
        - Creator empowerment and rewards
        
        ## Output Format:
        
        Please structure your tokenomics design as:
        
        # TUS Tokenomics Design: [Task Title]
        
        ## Token Overview
        [Purpose, vision, and core value proposition]
        
        ## Utility Mechanisms
        [Detailed list of token use cases with implementation details]
        
        ## Economic Model
        [Supply mechanics, distribution, inflation/deflation]
        
        ## Incentive Structure
        [Reward mechanisms and behavioral incentives]
        
        ## User Journey Mapping
        [How users interact with tokens throughout platform experience]
        
        ## Financial Projections
        [Economic scenarios and sustainability analysis]
        
        ## Risk Analysis
        [Economic risks and mitigation strategies]
        
        ## Implementation Phases
        [Rollout strategy with milestones and testing]
        
        ## Success Metrics
        [KPIs for measuring tokenomics effectiveness]
        
        ## Technical Requirements
        [Smart contract specifications and integration needs]
        
        Provide mathematically sound, economically viable tokenomics that creates sustainable value for all stakeholders.
        """
    }
} 