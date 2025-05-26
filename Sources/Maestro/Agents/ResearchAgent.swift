import Foundation

struct ResearchAgent: SpecialistAgent {
    let role = "Market Research Specialist"
    let skills = ["competitive analysis", "market research", "strategic thinking", "data analysis", "tool evaluation", "comparative analysis"]
    
    let qualityStandards: [AgentTask.QualityLevel: String] = [
        .standard: "Provide basic analysis with key findings and recommendations",
        .high: "Comprehensive analysis with detailed methodology, data sources, and strategic insights",
        .critical: "Exhaustive research with multiple data sources, risk analysis, and implementation roadmap"
    ]
    
    func execute(task: AgentTask, outputDirectoryPath: String) async throws -> TaskResult {
        print("🔍 \(role) starting task: \(task.title)")
        
        let prompt = createPrompt(for: task)
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
            // Decide if this error should make the task fail or just be a warning
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
} 