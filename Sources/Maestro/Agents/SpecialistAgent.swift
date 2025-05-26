import Foundation

protocol SpecialistAgent {
    var role: String { get }
    var skills: [String] { get }
    var qualityStandards: [AgentTask.QualityLevel: String] { get }
    
    func canHandle(task: AgentTask) -> Bool
    func execute(task: AgentTask, outputDirectoryPath: String) async throws -> TaskResult
    func createPrompt(for task: AgentTask) -> String
}

extension SpecialistAgent {
    func canHandle(task: AgentTask) -> Bool {
        return task.skillsNeeded.contains { skill in
            skills.contains(skill)
        }
    }
    
    func createPrompt(for task: AgentTask) -> String {
        let qualityGuidance = qualityStandards[task.qualityLevel] ?? "Standard quality implementation"
        
        return """
        You are a \(role) with expertise in: \(skills.joined(separator: ", "))
        
        TASK: \(task.title)
        GOAL: \(task.goal)
        
        ACCEPTANCE CRITERIA:
        \(task.acceptanceCriteria.enumerated().map { "- \($0.element)" }.joined(separator: "\n"))
        
        COMPLEXITY: \(task.complexity.rawValue)
        QUALITY LEVEL: \(task.qualityLevel.rawValue)
        QUALITY GUIDANCE: \(qualityGuidance)
        
        SKILLS NEEDED: \(task.skillsNeeded.joined(separator: ", "))
        RESOURCES: \(task.resources.joined(separator: ", "))
        
        TESTING REQUIREMENTS: \(task.testingRequirements)
        DOCUMENTATION REQUIREMENTS: \(task.documentationRequirements)
        
        SUCCESS INDICATORS:
        \(task.successIndicators.enumerated().map { "- \($0.element)" }.joined(separator: "\n"))
        
        Please complete this task according to the specified quality level and requirements.
        Provide a comprehensive response that meets all acceptance criteria.
        """
    }
} 