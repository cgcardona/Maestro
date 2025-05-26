import Foundation

struct TaskResult: Codable, Identifiable {
    let id = UUID()
    let taskId: UUID
    let content: String
    var status: AgentTask.TaskStatus
    var notes: String?
    var generatedFiles: [String]?
    var pullRequestURL: String?
    let completedAt: Date
    let qualityScore: Double?
    
    init(
        taskId: UUID,
        content: String,
        status: AgentTask.TaskStatus,
        notes: String? = nil,
        generatedFiles: [String]? = nil, 
        pullRequestURL: String? = nil,
        completedAt: Date = Date(),
        qualityScore: Double? = nil
    ) {
        self.taskId = taskId
        self.content = content
        self.status = status
        self.notes = notes
        self.generatedFiles = generatedFiles
        self.pullRequestURL = pullRequestURL
        self.completedAt = completedAt
        self.qualityScore = qualityScore
    }
} 