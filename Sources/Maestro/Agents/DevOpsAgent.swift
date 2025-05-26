import Foundation

struct DevOpsAgent: SpecialistAgent {
    let role = "DevOps Specialist"
    let skills = ["devops", "access management", "environment configuration", "infrastructure", "deployment", "ci/cd", "security", "monitoring", "automation"]
    
    let qualityStandards: [AgentTask.QualityLevel: String] = [
        .standard: "Basic environment setup with essential tools and access",
        .high: "Comprehensive development environment with automation, monitoring, and security best practices",
        .critical: "Production-grade infrastructure with full automation, security compliance, and disaster recovery"
    ]
    
    func execute(task: AgentTask, outputDirectoryPath: String) async throws -> TaskResult {
        print("⚙️ \(role) starting task: \(task.title)")
        
        let prompt = createDevOpsPrompt(for: task)
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
    
    private func createDevOpsPrompt(for task: AgentTask) -> String {
        let basePrompt = createPrompt(for: task)
        
        return """
        \(basePrompt)
        
        ## DevOps Implementation Guidelines:
        
        You are a senior DevOps engineer setting up infrastructure for TellUrStori development. Please provide:
        
        1. **Environment Setup**: Complete development environment configuration
        2. **Access Management**: Repository access, permissions, and security protocols
        3. **Tool Configuration**: IDE setup, build tools, testing frameworks
        4. **Automation**: CI/CD pipelines, deployment scripts, monitoring
        5. **Security**: Credential management, access controls, security scanning
        6. **Documentation**: Setup guides, troubleshooting, best practices
        
        ## TellUrStori Technical Context:
        - Native macOS application built with Swift/SwiftUI
        - Xcode development environment
        - Git-based version control
        - Multiple developers and contributors
        - Need for secure credential management
        - Integration with external APIs and services
        
        ## Output Format:
        
        Please structure your DevOps plan as:
        
        # DevOps Setup: [Task Title]
        
        ## Environment Requirements
        [System requirements and prerequisites]
        
        ## Setup Instructions
        [Step-by-step configuration guide]
        
        ```bash
        # Include actual commands and scripts
        ```
        
        ## Access Configuration
        [Repository access, permissions, and security setup]
        
        ## Tool Installation
        [Required tools and configuration]
        
        ## Automation Setup
        [CI/CD configuration and deployment scripts]
        
        ## Security Measures
        [Credential management and security protocols]
        
        ## Verification Steps
        [Testing and validation procedures]
        
        ## Troubleshooting Guide
        [Common issues and solutions]
        
        ## Maintenance Procedures
        [Ongoing maintenance and updates]
        
        Provide practical, executable DevOps solutions with actual commands and configurations.
        """
    }
} 