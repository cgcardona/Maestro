import Foundation

struct StrategyAgent: SpecialistAgent {
    let role = "Strategy Specialist"
    let skills = ["strategic planning", "project management", "resource planning", "priority matrix", "roadmap planning", "business analysis", "stakeholder management", "risk assessment"]
    
    let qualityStandards: [AgentTask.QualityLevel: String] = [
        .standard: "Clear strategic analysis with basic prioritization and resource allocation",
        .high: "Comprehensive strategic plan with detailed impact analysis, timelines, and risk mitigation",
        .critical: "Enterprise-grade strategic roadmap with stakeholder alignment, scenario planning, and success metrics"
    ]
    
    func execute(task: AgentTask, outputDirectoryPath: String) async throws -> TaskResult {
        print("🎯 \(role) starting task: \(task.title)")
        
        let prompt = createStrategyPrompt(for: task)
        let responseContent = try await AnthropicAPI.shared.complete(prompt: prompt)
        
        // Define filename and path for the output file
        let sanitizedTitle = task.title.replacingOccurrences(of: "[^a-zA-Z0-9_-\\.]", with: "_", options: .regularExpression)
        let outputFileName = "\(sanitizedTitle).md"
        let outputFilePath = URL(fileURLWithPath: outputDirectoryPath).appendingPathComponent(outputFileName).path
        
        // Save the response content to the file
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
    
    private func createStrategyPrompt(for task: AgentTask) -> String {
        let basePrompt = createPrompt(for: task)
        
        return """
        \(basePrompt)
        
        ## Strategic Analysis Guidelines:
        
        You are a senior strategy consultant working on TellUrStori, a native macOS storytelling app. Please provide:
        
        1. **Strategic Framework**: Use proven frameworks like SWOT, Impact/Effort Matrix, OKRs
        2. **Data-Driven Analysis**: Include quantitative metrics and scoring methodologies
        3. **Timeline Planning**: Create realistic timelines with dependencies and milestones
        4. **Resource Assessment**: Analyze team capacity, skills gaps, and budget requirements
        5. **Risk Management**: Identify potential blockers and mitigation strategies
        6. **Success Metrics**: Define clear KPIs and success indicators
        
        ## TellUrStori Context:
        - Native macOS storytelling application
        - Focus on multimedia narrative creation
        - Growing user base with engagement challenges
        - Competitive market with established players
        - Need for sustainable growth and monetization
        - Technical debt and feature prioritization challenges
        
        ## Output Format:
        
        Please structure your strategic analysis as:
        
        # Strategic Analysis: [Task Title]
        
        ## Executive Summary
        [Key findings and recommendations]
        
        ## Current State Analysis
        [Assessment of current situation]
        
        ## Strategic Options
        [Available paths forward with pros/cons]
        
        ## Recommended Approach
        [Detailed recommendation with rationale]
        
        ## Implementation Roadmap
        [Timeline with phases, milestones, and dependencies]
        
        ## Resource Requirements
        [Team, budget, and infrastructure needs]
        
        ## Risk Assessment
        [Potential challenges and mitigation strategies]
        
        ## Success Metrics
        [KPIs and measurement framework]
        
        Provide actionable, data-driven strategic guidance that enables immediate decision-making and execution.
        """
    }
} 