import Foundation

struct MentorAgent: SpecialistAgent {
    let role = "Technical Mentor"
    let skills = ["technical mentoring", "knowledge transfer", "communication planning", "onboarding", "training", "documentation", "team leadership", "skill development"]
    
    let qualityStandards: [AgentTask.QualityLevel: String] = [
        .standard: "Basic knowledge transfer with essential information and communication plan",
        .high: "Comprehensive mentoring program with structured learning path, documentation, and ongoing support",
        .critical: "Enterprise-grade knowledge transfer with detailed competency framework, assessment metrics, and long-term development planning"
    ]
    
    func execute(task: AgentTask, outputDirectoryPath: String) async throws -> TaskResult {
        print("👨‍🏫 \(role) starting task: \(task.title)")
        
        let prompt = createMentorPrompt(for: task)
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
    
    private func createMentorPrompt(for task: AgentTask) -> String {
        let basePrompt = createPrompt(for: task)
        
        return """
        \(basePrompt)
        
        ## Technical Mentoring Guidelines:
        
        You are a senior technical mentor facilitating knowledge transfer for TellUrStori development. Please provide:
        
        1. **Knowledge Assessment**: Evaluate current skill levels and knowledge gaps
        2. **Learning Path Design**: Structured approach to knowledge acquisition
        3. **Communication Strategy**: Effective knowledge transfer methods and channels
        4. **Documentation Framework**: Essential documentation and reference materials
        5. **Support Structure**: Ongoing mentoring and escalation procedures
        6. **Progress Tracking**: Milestones and competency validation methods
        
        ## TellUrStori Technical Context:
        - Native macOS application built with Swift/SwiftUI
        - MVVM architecture with modern development patterns
        - Complex codebase with multiple integration points
        - Team collaboration and knowledge sharing needs
        - Rapid development cycles requiring efficient onboarding
        - Quality standards and best practices enforcement
        
        ## Mentoring Principles:
        - Adult learning theory and effective knowledge transfer
        - Hands-on learning with practical examples
        - Progressive complexity and skill building
        - Clear communication and feedback loops
        - Sustainable knowledge sharing practices
        - Empowerment and autonomous development
        
        ## Output Format:
        
        Please structure your mentoring plan as:
        
        # Technical Mentoring Plan: [Task Title]
        
        ## Knowledge Assessment
        [Current skill evaluation and gap analysis]
        
        ## Learning Objectives
        [Clear, measurable learning goals and outcomes]
        
        ## Knowledge Transfer Strategy
        [Structured approach to information sharing]
        
        ## Session Planning
        [Detailed walkthrough sessions with agendas and materials]
        
        ### Session 1: Architecture Overview
        - **Duration**: X hours
        - **Objectives**: [Specific learning goals]
        - **Materials**: [Documentation, diagrams, code examples]
        - **Activities**: [Hands-on exercises and discussions]
        
        ## Documentation Package
        [Essential reference materials and guides]
        
        ## Communication Framework
        [Regular check-ins, feedback mechanisms, and escalation paths]
        
        ## Competency Validation
        [Methods to verify understanding and skill acquisition]
        
        ## Ongoing Support Structure
        [Long-term mentoring and development planning]
        
        ## Success Metrics
        [Measurable indicators of effective knowledge transfer]
        
        ## Risk Mitigation
        [Common challenges and solutions in knowledge transfer]
        
        Provide practical, empathetic mentoring guidance that enables rapid skill development and autonomous contribution.
        """
    }
} 