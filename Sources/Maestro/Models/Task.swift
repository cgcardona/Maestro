import Foundation

struct AgentTask: Codable, Identifiable {
    let id = UUID()
    let title: String
    let goal: String
    let acceptanceCriteria: [String]
    let complexity: Complexity
    let qualityLevel: QualityLevel
    let skillsNeeded: [String]
    let resources: [String]
    let testingRequirements: String
    let documentationRequirements: String
    let successIndicators: [String]
    var status: TaskStatus = .notStarted
    
    enum Complexity: String, Codable, CaseIterable {
        case simple = "Simple"
        case medium = "Medium"
        case complex = "Complex"
    }
    
    enum QualityLevel: String, Codable, CaseIterable {
        case standard = "Standard"
        case high = "High"
        case critical = "Critical"
    }
    
    enum TaskStatus: String, Codable, CaseIterable {
        case notStarted = "Not Started"
        case inProgress = "In Progress"
        case completed = "Completed"
        case failed = "Failed"
    }
    
    var isCompleted: Bool {
        return status == .completed
    }
} 