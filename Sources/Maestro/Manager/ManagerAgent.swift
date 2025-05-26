import Foundation

extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

class ManagerAgent {
    static let shared = ManagerAgent()
    
    private let specialists: [SpecialistAgent] = [
        ResearchAgent(),
        SwiftDeveloperAgent(),
        QAReviewAgent(),
        DocumentationAgent(),
        StrategyAgent(),
        DevOpsAgent(),
        TokenomicsAgent(),
        TechnicalResearchAgent(),
        InfrastructureAgent(),
        MentorAgent(),
        ArchitectureAgent()
    ]
    
    private var taskQueue: [AgentTask] = []
    private var completedTasks: [TaskResult] = []
    private var activeTasks: [UUID: AgentTask] = [:]
    private var standupFilePath: String?
    private var standupFileDirectory: String?
    private var currentRunOutputDirectoryPath: String?
    
    private init() {}
    
    // MARK: - Public Interface
    
    func loadTasksFromStandup(_ standupFile: String) async throws -> [AgentTask] {
        print("📋 Loading tasks from standup file: \(standupFile)")
        
        // Resolve the absolute path of the standup file
        let fileManager = FileManager.default
        let absoluteStandupPath: String
        if standupFile.hasPrefix("/") { // Already an absolute path
            absoluteStandupPath = standupFile
        } else { // Relative path, resolve against current working directory
            absoluteStandupPath = fileManager.currentDirectoryPath + "/" + standupFile
        }
        
        // Normalize the path (e.g., resolve "../")
        let normalizedStandupPath = URL(fileURLWithPath: absoluteStandupPath).standardized.path
        
        guard fileManager.fileExists(atPath: normalizedStandupPath) else {
            throw ManagerError.fileNotFound(normalizedStandupPath)
        }

        self.standupFilePath = normalizedStandupPath
        // Store the directory of the standup file for outputting other files
        self.standupFileDirectory = URL(fileURLWithPath: normalizedStandupPath).deletingLastPathComponent().path

        let tasks = try parseStandupFile(normalizedStandupPath)
        
        // Filter out already completed tasks
        let incompleteTasks = tasks.filter { !$0.isCompleted }
        let completedCount = tasks.count - incompleteTasks.count
        
        taskQueue.append(contentsOf: incompleteTasks)
        
        if completedCount > 0 {
            print("⏭️ Skipping \(completedCount) already completed tasks")
        }
        print("✅ Loaded \(incompleteTasks.count) incomplete tasks")
        return incompleteTasks
    }
    
    func executeAllTasks() async throws -> ExecutionSummary {
        // Setup run-specific output directory
        let runTimestamp = Int(Date().timeIntervalSince1970)
        let fileManager = FileManager.default
        let baseReportsDir = "reports" // Assuming top-level reports directory relative to current working dir

        // Ensure currentDirectoryPath is appropriate or make it absolute from project root if needed
        let projectRootPath = fileManager.currentDirectoryPath 
        let reportsRootPath = URL(fileURLWithPath: projectRootPath).appendingPathComponent(baseReportsDir).path

        self.currentRunOutputDirectoryPath = URL(fileURLWithPath: reportsRootPath)
                                                 .appendingPathComponent("\(runTimestamp)")
                                                 .path
        
        do {
            try fileManager.createDirectory(atPath: self.currentRunOutputDirectoryPath!, 
                                            withIntermediateDirectories: true, 
                                            attributes: nil)
            print("💾 Run output will be saved to: \(self.currentRunOutputDirectoryPath!)")
        } catch {
            // If we can't create this, it's a critical issue for saving progress/reports.
            print("🚨 CRITICAL: Could not create run-specific output directory: \(self.currentRunOutputDirectoryPath!). Error: \(error.localizedDescription)")
            throw ManagerError.cannotCreateOutputDirectory(self.currentRunOutputDirectoryPath ?? "Unknown Path")
        }

        print("🚀 Manager Agent starting execution of \(taskQueue.count) tasks")
        
        let startTime = Date()
        var successCount = 0
        var failureCount = 0
        
        for task in taskQueue {
            do {
                let result = try await executeTask(task)
                completedTasks.append(result)
                
                if result.status == .completed {
                    successCount += 1
                    print("✅ Task completed: \(task.title)")
                } else {
                    failureCount += 1
                    print("❌ Task failed: \(task.title)")
                }
                
                // Update standup file with completion status
                try await updateStandupFileStatus(task: task, result: result)
                
                // Save progress after each task
                try await saveProgress()
                
            } catch {
                failureCount += 1
                print("❌ Task error: \(task.title) - \(error.localizedDescription)")
                
                // Create failure result
                let failureResult = TaskResult(
                    taskId: task.id,
                    content: "Task failed with error: \(error.localizedDescription)",
                    status: .failed,
                    notes: "Execution failed: \(error)"
                )
                completedTasks.append(failureResult)
                
                // Update standup file with failure status
                try? await updateStandupFileStatus(task: task, result: failureResult)
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        let summary = ExecutionSummary(
            totalTasks: taskQueue.count,
            successCount: successCount,
            failureCount: failureCount,
            duration: duration,
            results: completedTasks
        )
        
        try await generateExecutionReport(summary)
        
        print("🎯 Execution complete: \(successCount)/\(taskQueue.count) tasks successful")
        return summary
    }
    
    func executeTask(_ task: AgentTask) async throws -> TaskResult {
        print("🎯 Manager assigning task: \(task.title)")
        
        // Find the best agent for this task
        guard let agent = findBestAgent(for: task) else {
            throw ManagerError.noSuitableAgent(task.title)
        }
        
        print("👤 Assigned to: \(agent.role)")
        activeTasks[task.id] = task
        
        // Execute the task, passing the currentRunOutputDirectoryPath
        guard let runOutputDir = currentRunOutputDirectoryPath else {
            // This should ideally not happen if executeAllTasks set it up correctly
            throw ManagerError.cannotCreateOutputDirectory("Output directory path not available for task execution.")
        }
        let result = try await agent.execute(task: task, outputDirectoryPath: runOutputDir)
        activeTasks.removeValue(forKey: task.id)
        
        return result
    }
    
    // MARK: - Task Assignment Logic
    
    private func findBestAgent(for task: AgentTask) -> SpecialistAgent? {
        var bestAgent: SpecialistAgent?
        var bestScore = 0
        
        for agent in specialists {
            let score = calculateAgentScore(agent: agent, task: task)
            if score > bestScore && agent.canHandle(task: task) {
                bestScore = score
                bestAgent = agent
            }
        }
        
        return bestAgent
    }
    
    private func calculateAgentScore(agent: SpecialistAgent, task: AgentTask) -> Int {
        var score = 0
        
        // Score based on skill matching
        for skill in task.skillsNeeded {
            if agent.skills.contains(where: { $0.lowercased() == skill.lowercased() }) {
                score += 10
            }
        }
        
        // Bonus for exact role matches
        if task.skillsNeeded.contains(where: { skill in
            agent.role.lowercased().contains(skill.lowercased())
        }) {
            score += 5
        }
        
        return score
    }
    
    // MARK: - File Parsing
    
    private func parseStandupFile(_ filePath: String) throws -> [AgentTask] {
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        return try parseMarkdownTasks(content)
    }
    
    private func parseMarkdownTasks(_ content: String) throws -> [AgentTask] {
        var tasks: [AgentTask] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentTask: TaskBuilder?
        var inTaskSection = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            var lineForTaskDetection = trimmed
            if trimmed.hasPrefix("✅ ") || trimmed.hasPrefix("❌ ") || trimmed.hasPrefix("🔄 ") {
                lineForTaskDetection = String(trimmed.dropFirst(2))
            }
            
            // Detect task headers (**Task X**: or ### Task X:)
            if (lineForTaskDetection.hasPrefix("**Task") && (lineForTaskDetection.contains("**:") || lineForTaskDetection.contains("**: "))) || 
               (lineForTaskDetection.hasPrefix("### Task") && lineForTaskDetection.contains(":")) {
                // Save previous task if exists
                if let builder = currentTask {
                    if let task = try? builder.build() {
                        tasks.append(task)
                    }
                }
                
                // Start new task using the original trimmed line for title and status extraction
                let title = extractTaskTitle(from: trimmed) 
                let status = extractTaskStatus(from: trimmed)
                currentTask = TaskBuilder(title: title, status: status)
                inTaskSection = true
                continue
            }
            
            // Skip if not in a task section
            guard inTaskSection, let builder = currentTask else { continue }
            
            // Parse task properties
            if lineForTaskDetection.hasPrefix("**Goal:**") || lineForTaskDetection.hasPrefix("- **Goal**:") {
                let prefix = lineForTaskDetection.hasPrefix("- **Goal**:") ? "- **Goal**:" : "**Goal:**"
                builder.goal = extractValue(from: lineForTaskDetection, prefix: prefix)
            } else if lineForTaskDetection.hasPrefix("**Acceptance Criteria:**") || lineForTaskDetection.hasPrefix("- **Acceptance Criteria**:") {
                // Next lines will be criteria
                continue
            } else if lineForTaskDetection.hasPrefix("- [ ]") || lineForTaskDetection.hasPrefix("- [x]") {
                // This is acceptance criteria with checkboxes
                let criterion = String(lineForTaskDetection.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                builder.acceptanceCriteria.append(criterion)
            } else if lineForTaskDetection.hasPrefix("- ") && builder.goal != nil && !lineForTaskDetection.contains("**") {
                // This is likely acceptance criteria without checkboxes
                let criterion = String(lineForTaskDetection.dropFirst(2))
                builder.acceptanceCriteria.append(criterion)
            } else if lineForTaskDetection.hasPrefix("**Complexity:**") || lineForTaskDetection.hasPrefix("- **Complexity**:") {
                let prefix = lineForTaskDetection.hasPrefix("- **Complexity**:") ? "- **Complexity**:" : "**Complexity:**"
                let complexityStr = extractValue(from: lineForTaskDetection, prefix: prefix)
                builder.complexity = AgentTask.Complexity(rawValue: complexityStr) ?? .medium
            } else if lineForTaskDetection.hasPrefix("**Quality Level:**") || lineForTaskDetection.hasPrefix("- **Quality Level**:") {
                let prefix = lineForTaskDetection.hasPrefix("- **Quality Level**:") ? "- **Quality Level**:" : "**Quality Level:**"
                let qualityStr = extractValue(from: lineForTaskDetection, prefix: prefix)
                builder.qualityLevel = AgentTask.QualityLevel(rawValue: qualityStr) ?? .standard
            } else if lineForTaskDetection.hasPrefix("**Skills Needed:**") || lineForTaskDetection.hasPrefix("- **Skills Needed**:") || lineForTaskDetection.hasPrefix("**SkillsNeeded:**") || lineForTaskDetection.hasPrefix("- **SkillsNeeded**:") {
                var prefix = ""
                if lineForTaskDetection.hasPrefix("- **Skills Needed**:") { prefix = "- **Skills Needed**:" }
                else if lineForTaskDetection.hasPrefix("**Skills Needed:**") { prefix = "**Skills Needed:**" }
                else if lineForTaskDetection.hasPrefix("- **SkillsNeeded**:") { prefix = "- **SkillsNeeded**:" }
                else if lineForTaskDetection.hasPrefix("**SkillsNeeded:**") { prefix = "**SkillsNeeded:**" }
                let skillsStr = extractValue(from: lineForTaskDetection, prefix: prefix)
                builder.skillsNeeded = skillsStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            } else if lineForTaskDetection.hasPrefix("**Resources:**") || lineForTaskDetection.hasPrefix("- **Resources**:") {
                let prefix = lineForTaskDetection.hasPrefix("- **Resources**:") ? "- **Resources**:" : "**Resources:**"
                let resourcesStr = extractValue(from: lineForTaskDetection, prefix: prefix)
                builder.resources = resourcesStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            } else if lineForTaskDetection.hasPrefix("**Testing Requirements:**") || lineForTaskDetection.hasPrefix("- **Testing Requirements**:") {
                let prefix = lineForTaskDetection.hasPrefix("- **Testing Requirements**:") ? "- **Testing Requirements**:" : "**Testing Requirements:**"
                builder.testingRequirements = extractValue(from: lineForTaskDetection, prefix: prefix)
            } else if lineForTaskDetection.hasPrefix("**Documentation Requirements:**") || lineForTaskDetection.hasPrefix("- **Documentation Requirements**:") {
                let prefix = lineForTaskDetection.hasPrefix("- **Documentation Requirements**:") ? "- **Documentation Requirements**:" : "**Documentation Requirements:**"
                builder.documentationRequirements = extractValue(from: lineForTaskDetection, prefix: prefix)
            } else if lineForTaskDetection.hasPrefix("**Success Indicators:**") || lineForTaskDetection.hasPrefix("- **Success Indicators**:") {
                let prefix = lineForTaskDetection.hasPrefix("- **Success Indicators**:") ? "- **Success Indicators**:" : "**Success Indicators:**"
                let indicatorsStr = extractValue(from: lineForTaskDetection, prefix: prefix)
                builder.successIndicators = [indicatorsStr]
            }
        }
        
        // Save last task
        if let builder = currentTask {
            if let task = try? builder.build() {
                tasks.append(task)
            }
        }
        
        return tasks
    }
    
    private func extractTaskTitle(from line: String) -> String {
        var tempLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Strip status emojis prefix (leading)
        if tempLine.hasPrefix("✅ ") { tempLine = String(tempLine.dropFirst(2)); tempLine = tempLine.trimmingCharacters(in: .whitespacesAndNewlines) }
        else if tempLine.hasPrefix("❌ ") { tempLine = String(tempLine.dropFirst(2)); tempLine = tempLine.trimmingCharacters(in: .whitespacesAndNewlines) }
        else if tempLine.hasPrefix("🔄 ") { tempLine = String(tempLine.dropFirst(2)); tempLine = tempLine.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // 2. Strip timestamp suffix like " *(completed: ...)*" (trailing)
        // Ensure there's a space before the parenthesis of the timestamp.
        if let timestampRange = tempLine.range(of: " *(completed:") {
            tempLine = String(tempLine[..<timestampRange.lowerBound])
            tempLine = tempLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 3. Now, tempLine should be like "**Task X**: Title" or "### Task Y: Title"
        // Apply original-style logic to this cleaned tempLine:
        if tempLine.contains("**: ") { // Format: **Task X**: Title
            if let range = tempLine.range(of: "**: ") {
                return String(tempLine[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        } else if tempLine.contains("**:") { // Format: **Task X**:Title (no space after bold colon)
            if let range = tempLine.range(of: "**:") {
                return String(tempLine[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        } else if let colonIndex = tempLine.firstIndex(of: ":") {
            // For "### Task X: Title" or "Task X: Title" (normal colon)
            let prefixPart = String(tempLine[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            // Check if the prefix part is a task identifier like "### Task X", "**Task X**", or "Task X"
            if prefixPart.hasPrefix("### Task") || prefixPart.hasPrefix("**Task") || 
               prefixPart.range(of:#"^Task\s*\d+"#, options: .regularExpression) != nil || // "Task <number>"
               prefixPart == "Task" { // Simply "Task: Title" - less common but possible
                return String(tempLine[tempLine.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            }
        }
        // If no structure matched, but the line might have been cleaned to just the title,
        // it's safer to return "Untitled Task" to avoid returning a malformed part of the line.
        // The calling context (parser) usually expects this for non-matching lines.
        return "Untitled Task" 
    }
    
    private func extractValue(from line: String, prefix: String) -> String {
        return line.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespaces)
    }
    
    private func extractTaskStatus(from line: String) -> AgentTask.TaskStatus {
        // Look for status indicators like ✅, ❌, 🔄
        if line.contains("✅") {
            return .completed
        } else if line.contains("❌") {
            return .failed
        } else if line.contains("🔄") {
            return .inProgress
        }
        return .notStarted
    }
    
    // MARK: - Standup File Updates
    
    private func updateStandupFileStatus(task: AgentTask, result: TaskResult) async throws {
        guard let filePath = standupFilePath else { 
            print("🚨 Error: Standup file path not set. Cannot update status.")
            return 
        }
        
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        let updatedContent = updateTaskStatusInMarkdown(content: content, task: task, result: result)
        
        try updatedContent.write(toFile: filePath, atomically: true, encoding: .utf8)
        print("📝 Updated standup file with task status: \(task.title)")
    }
    
    private func updateTaskStatusInMarkdown(content: String, task: AgentTask, result: TaskResult) -> String {
        let lines = content.components(separatedBy: .newlines)
        var updatedLines: [String] = []
        var inTargetTaskBlock = false
        var statusLineUpdatedForBlock = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            var lineToAppend = line

            // Check if this line is a task header
            let isTaskHeader = (trimmedLine.hasPrefix("**Task") && (trimmedLine.contains("**: ") || trimmedLine.contains("**:"))) ||
                               (trimmedLine.hasPrefix("### Task") && trimmedLine.contains(":")) ||
                               (trimmedLine.hasPrefix("✅ **Task") && (trimmedLine.contains("**: ") || trimmedLine.contains("**:"))) ||
                               (trimmedLine.hasPrefix("❌ **Task") && (trimmedLine.contains("**: ") || trimmedLine.contains("**:"))) ||
                               (trimmedLine.hasPrefix("🔄 **Task") && (trimmedLine.contains("**: ") || trimmedLine.contains("**:")))


            if isTaskHeader {
                // Reset flags if we are entering a new task block
                inTargetTaskBlock = false
                statusLineUpdatedForBlock = false
                
                let lineTitle = extractTaskTitle(from: trimmedLine) // Use original trimmedLine for title extraction

                if lineTitle == task.title {
                    inTargetTaskBlock = true // We are now inside the block of the task we want to update

                    // Update this line with status emoji and timestamp
                    let statusEmoji = result.status == .completed ? "✅" : (result.status == .failed ? "❌" : "🔄")
                    let timestamp = DateFormatter.shortDateTime.string(from: Date())
                    
                    // Remove any existing status emojis and timestamp from the task title line
                    var baseTaskLine = trimmedLine // Start with the current trimmed line
                    // First, remove the timestamp part to avoid issues with emoji removal if emoji is part of timestamp (unlikely but safe)
                    if let range = baseTaskLine.range(of: " *(completed:") {
                        baseTaskLine = String(baseTaskLine[..<range.lowerBound])
                    }
                    // Then, remove leading emojis
                    if baseTaskLine.hasPrefix("✅ ") { baseTaskLine = String(baseTaskLine.dropFirst(2)) }
                    else if baseTaskLine.hasPrefix("❌ ") { baseTaskLine = String(baseTaskLine.dropFirst(2)) }
                    else if baseTaskLine.hasPrefix("🔄 ") { baseTaskLine = String(baseTaskLine.dropFirst(2)) }
                    
                    baseTaskLine = baseTaskLine.trimmingCharacters(in: .whitespacesAndNewlines) // Ensure it's clean

                    // The baseTaskLine now contains the core task definition, e.g., "**Task X**: Title"
                    lineToAppend = "\(statusEmoji) \(baseTaskLine) *(completed: \(timestamp))*"
                }
            } else if inTargetTaskBlock && !statusLineUpdatedForBlock {
                // We are inside the target task's block, look for the status line
                if trimmedLine.hasPrefix("- Status:") || trimmedLine.hasPrefix("**Status:**") {
                    let prefix = trimmedLine.hasPrefix("- Status:") ? "- Status:" : "**Status:**"
                    let leadingWhitespace = line.prefix(while: { $0.isWhitespace })
                    lineToAppend = "\(leadingWhitespace)\(prefix) \(result.status.rawValue)"
                    statusLineUpdatedForBlock = true // Mark as updated for this block
                    
                    // Append the updated status line, then add generated files/PR info if completed
                    updatedLines.append(lineToAppend)

                    if result.status == .completed {
                        var extraInfoLines: [String] = []
                        if let files = result.generatedFiles, !files.isEmpty {
                            extraInfoLines.append("\(leadingWhitespace)- Generated Files:")
                            files.forEach { extraInfoLines.append("\(leadingWhitespace)  - \($0)") }
                        }
                        if let prURL = result.pullRequestURL, !prURL.isEmpty {
                            extraInfoLines.append("\(leadingWhitespace)- Pull Request: [link](\(prURL))")
                        }
                        if !extraInfoLines.isEmpty {
                            updatedLines.append(contentsOf: extraInfoLines)
                        }
                    }
                    continue // crucial: we've handled appending lines for this original line, so skip the final append
                }
            }
            updatedLines.append(lineToAppend) // Default append for lines not specially handled
        }
        
        return updatedLines.joined(separator: "\n")
    }
    
    // MARK: - Progress & Reporting
    
    private func saveProgress() async throws {
        guard let outputDir = currentRunOutputDirectoryPath else {
            print("🚨 Error: Run output directory not set. Cannot save progress.")
            return
        }
        let fileTimestamp = Int(Date().timeIntervalSince1970) // Renamed to avoid conflict
        let progressFileName = "execution-progress-\(fileTimestamp).md" // Changed extension to .md
        let progressFile = URL(fileURLWithPath: outputDir).appendingPathComponent(progressFileName).path
        
        // Create an instance of ExecutionProgress to access its data
        // Note: `taskQueue` refers to all initially loaded incomplete tasks for the current run.
        // `completedTasks` accumulates all tasks completed across potentially multiple `saveProgress` calls in a single run.
        let currentProgress = ExecutionProgress(
            completedTasks: self.completedTasks, // Tasks completed so far in this run
            remainingTasks: self.taskQueue.count - self.completedTasks.count, // Tasks from initial queue yet to be completed
            activeTasks: Array(self.activeTasks.values) // Tasks currently being processed
        )

        var markdownContent = """
        # Agent Orchestrator Execution Progress

        **Generated:** \(DateFormatter.shortDateTime.string(from: Date()))
        
        ## Overall Progress Summary
        - 🔵 **Total Tasks in Queue (for this run):** \(self.taskQueue.count)
        - ✅ **Completed Tasks (so far this run):** \(currentProgress.completedTasks.count)
        - ⏳ **Remaining Tasks (in queue):** \(currentProgress.remainingTasks)
        - 🔄 **Active Tasks (currently processing):** \(currentProgress.activeTasks.count)
        """

        if !currentProgress.activeTasks.isEmpty {
            markdownContent += "\n\n        ## 🔄 Active Tasks\n"
            for (index, task) in currentProgress.activeTasks.enumerated() {
                markdownContent += """
                ### \(index + 1). \(task.title)
                - **Goal:** \(task.goal)
                - **Complexity:** \(task.complexity.rawValue)
                - **Status:** \(task.status.rawValue)
                ---
                """
            }
        }

        if !currentProgress.completedTasks.isEmpty {
            markdownContent += "\n\n        ## ✅ Completed Tasks (This Run)\n"
            for (index, result) in currentProgress.completedTasks.enumerated() {
                // Attempt to find the original task details for more context if needed
                // This part assumes `result.taskId` can be used to fetch more details if necessary
                // For now, we'll use what's available in TaskResult and try to find the title from active or queued tasks.
                let taskTitle = activeTasks[result.taskId]?.title ?? taskQueue.first(where: { $0.id == result.taskId })?.title ?? "Unknown Task (ID: \(result.taskId))"
                let statusEmoji = result.status == .completed ? "✅" : "❌"
                
                markdownContent += """
                ### \(index + 1). \(statusEmoji) \(taskTitle)
                - **Task ID:** \(result.taskId)
                - **Status:** \(result.status.rawValue)
                - **Completed At:** \(DateFormatter.shortDateTime.string(from: result.completedAt))
                - **Notes:** \(result.notes ?? "None")
                **Content Preview:**
                ```
                \(String(result.content.prefix(200)))...
                ```
                ---
                """
            }
        }
        
        try markdownContent.write(to: URL(fileURLWithPath: progressFile), atomically: true, encoding: .utf8)
        
        print("💾 Progress saved to: \(progressFile)")
    }
    
    private func generateExecutionReport(_ summary: ExecutionSummary) async throws {
        guard let outputDir = currentRunOutputDirectoryPath else {
            print("🚨 Error: Run output directory not set. Cannot generate report.")
            return
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let reportFileName = "execution-report-\(timestamp).md"
        let reportFile = URL(fileURLWithPath: outputDir).appendingPathComponent(reportFileName).path
        
        let report = """
        # Agent Orchestrator Execution Report
        
        **Generated:** \(Date())
        **Duration:** \(String(format: "%.2f", summary.duration)) seconds
        **Success Rate:** \(summary.successCount)/\(summary.totalTasks) (\(summary.totalTasks > 0 ? Int(Double(summary.successCount)/Double(summary.totalTasks) * 100) : 0)%)
        
        ## Summary
        - ✅ **Successful Tasks:** \(summary.successCount)
        - ❌ **Failed Tasks:** \(summary.failureCount)
        - ⏱️ **Average Time per Task:** \(summary.totalTasks > 0 ? String(format: "%.2f", summary.duration / Double(summary.totalTasks)) : "0.00") seconds
        
        ## Task Results
        
        \(summary.results.enumerated().map { index, result in
            let status = result.status == .completed ? "✅" : "❌"
            return """
            ### \(index + 1). \(status) Task \(result.taskId)
            **Status:** \(result.status.rawValue)
            **Completed:** \(result.completedAt)
            **Notes:** \(result.notes ?? "None")
            
            **Content Preview:**
            ```
            \(String(result.content.prefix(200)))...
            ```
            
            ---
            """
        }.joined(separator: "\n"))
        
        ## Next Steps
        
        \(summary.failureCount > 0 ? """
        ### Failed Tasks Require Attention
        - Review failed task logs
        - Check agent configurations
        - Retry failed tasks if needed
        """ : """
        ### All Tasks Completed Successfully! 🎉
        - Review generated code and PRs
        - Conduct human QA review
        - Merge approved changes
        """)
        """
        
        try report.write(toFile: reportFile, atomically: true, encoding: .utf8)
        print("📊 Execution report saved to: \(reportFile)")
    }
}

// MARK: - Supporting Types

class TaskBuilder {
    let title: String
    var goal: String?
    var acceptanceCriteria: [String] = []
    var complexity: AgentTask.Complexity = .medium
    var qualityLevel: AgentTask.QualityLevel = .standard
    var skillsNeeded: [String] = []
    var resources: [String] = []
    var testingRequirements: String = ""
    var documentationRequirements: String = ""
    var successIndicators: [String] = []
    var status: AgentTask.TaskStatus = .notStarted
    
    init(title: String, status: AgentTask.TaskStatus = .notStarted) {
        self.title = title
        self.status = status
    }
    
    func build() throws -> AgentTask {
        guard let goal = goal else {
            throw ManagerError.incompleteTask(title)
        }
        
        var task = AgentTask(
            title: title,
            goal: goal,
            acceptanceCriteria: acceptanceCriteria.isEmpty ? ["Task completed successfully"] : acceptanceCriteria,
            complexity: complexity,
            qualityLevel: qualityLevel,
            skillsNeeded: skillsNeeded.isEmpty ? ["general"] : skillsNeeded,
            resources: resources,
            testingRequirements: testingRequirements.isEmpty ? "Basic validation" : testingRequirements,
            documentationRequirements: documentationRequirements.isEmpty ? "Update relevant documentation" : documentationRequirements,
            successIndicators: successIndicators.isEmpty ? ["Task objectives met"] : successIndicators
        )
        task.status = status
        return task
    }
}

struct ExecutionSummary: Codable {
    let totalTasks: Int
    let successCount: Int
    let failureCount: Int
    let duration: TimeInterval
    let results: [TaskResult]
}

struct ExecutionProgress: Codable {
    let completedTasks: [TaskResult]
    let remainingTasks: Int
    let activeTasks: [AgentTask]
}

enum ManagerError: Error {
    case noSuitableAgent(String)
    case incompleteTask(String)
    case fileNotFound(String)
    case cannotCreateOutputDirectory(String)
    
    var localizedDescription: String {
        switch self {
        case .noSuitableAgent(let taskTitle):
            return "No suitable agent found for task: \(taskTitle)"
        case .incompleteTask(let taskTitle):
            return "Incomplete task definition: \(taskTitle)"
        case .fileNotFound(let filePath):
            return "File not found: \(filePath)"
        case .cannotCreateOutputDirectory(let path):
            return "Cannot create output directory at path: \(path)"
        }
    }
} 