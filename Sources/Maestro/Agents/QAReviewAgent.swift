import Foundation

struct QAReviewAgent: SpecialistAgent {
    let role = "QA Review Specialist"
    let skills = ["code review", "quality assurance", "testing", "security review", "performance analysis"]
    
    let qualityStandards: [AgentTask.QualityLevel: String] = [
        .standard: "Basic code review focusing on functionality and obvious issues",
        .high: "Comprehensive review including performance, security, and maintainability",
        .critical: "Exhaustive review with security audit, performance profiling, and architectural assessment"
    ]
    
    func execute(task: AgentTask, outputDirectoryPath: String) async throws -> TaskResult {
        print("🔍 \(role) starting review: \(task.title)")
        
        // Extract PR information from task
        guard let prUrl = extractPRUrl(from: task) else {
            throw QAReviewError.noPRFound
        }
        
        // Get PR details and diff
        let prDetails = try await getPRDetails(prUrl)
        let diffContent = try await getPRDiff(prUrl)
        
        // Perform automated checks
        let automatedChecks = try await runAutomatedChecks(prDetails)
        
        // Generate AI review
        let reviewPrompt = createReviewPrompt(task: task, prDetails: prDetails, diff: diffContent, automatedChecks: automatedChecks)
        let aiReview = try await AnthropicAPI.shared.complete(prompt: reviewPrompt)
        
        // Parse review and create feedback
        let reviewResult = parseReviewResult(aiReview)
        
        // Post review comments if configured
        if let githubToken = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] {
            try await postReviewComments(prUrl: prUrl, review: reviewResult, token: githubToken)
        }
        
        print("✅ \(role) completed review: \(task.title)")
        
        let resultContent = """
        # QA Review Report
        
        ## PR: \(prDetails.title)
        **URL**: \(prUrl)
        **Author**: \(prDetails.author)
        **Branch**: \(prDetails.branch)
        
        ## Automated Checks
        \(formatAutomatedChecks(automatedChecks))
        
        ## AI Review Summary
        **Overall Rating**: \(reviewResult.overallRating)/10
        **Recommendation**: \(reviewResult.recommendation.rawValue)
        
        ### Strengths
        \(reviewResult.strengths.map { "- \($0)" }.joined(separator: "\n"))
        
        ### Issues Found
        \(reviewResult.issues.map { "- **\($0.severity.rawValue)**: \($0.description)" }.joined(separator: "\n"))
        
        ### Recommendations
        \(reviewResult.recommendations.map { "- \($0)" }.joined(separator: "\n"))
        
        ## Detailed Review
        \(aiReview)
        """
        
        return TaskResult(
            taskId: task.id,
            content: resultContent,
            status: .completed,
            notes: "QA review completed for PR \(prUrl) with rating \(reviewResult.overallRating)/10"
        )
    }
    
    private func extractPRUrl(from task: AgentTask) -> String? {
        // Look for PR URL in task resources or goal
        let text = "\(task.goal) \(task.resources.joined(separator: " "))"
        let pattern = #"https://github\.com/[^/]+/[^/]+/pull/\d+"#
        
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range])
        }
        
        return nil
    }
    
    private func getPRDetails(_ prUrl: String) async throws -> PRDetails {
        // Use GitHub CLI to get PR details
        let command = "gh pr view \(prUrl) --json title,author,headRefName,baseRefName,state"
        let output = try await runCommand(command)
        
        guard let data = output.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw QAReviewError.invalidPRData
        }
        
        return PRDetails(
            title: json["title"] as? String ?? "",
            author: (json["author"] as? [String: Any])?["login"] as? String ?? "",
            branch: json["headRefName"] as? String ?? "",
            baseBranch: json["baseRefName"] as? String ?? "",
            state: json["state"] as? String ?? ""
        )
    }
    
    private func getPRDiff(_ prUrl: String) async throws -> String {
        let command = "gh pr diff \(prUrl)"
        return try await runCommand(command)
    }
    
    private func runAutomatedChecks(_ prDetails: PRDetails) async throws -> AutomatedChecks {
        var checks = AutomatedChecks()
        
        // Check if build passes
        let buildCommand = "gh pr checks \(prDetails.title) --json state,conclusion"
        let buildOutput = try await runCommand(buildCommand)
        checks.buildPassing = buildOutput.contains("\"conclusion\":\"success\"")
        
        // Check for test coverage (if available)
        // This would integrate with your test coverage tools
        checks.testCoverage = nil
        
        // Check for security issues (basic)
        checks.securityIssues = []
        
        // Check for performance concerns
        checks.performanceConcerns = []
        
        return checks
    }
    
    private func createReviewPrompt(task: AgentTask, prDetails: PRDetails, diff: String, automatedChecks: AutomatedChecks) -> String {
        return """
        You are a senior QA engineer reviewing a Pull Request for TellUrStori, a native macOS storytelling app.
        
        ## PR Details
        - **Title**: \(prDetails.title)
        - **Author**: \(prDetails.author)
        - **Branch**: \(prDetails.branch) → \(prDetails.baseBranch)
        
        ## Quality Level: \(task.qualityLevel.rawValue)
        
        ## Automated Checks
        - Build Status: \(automatedChecks.buildPassing ? "✅ Passing" : "❌ Failing")
        - Test Coverage: \(automatedChecks.testCoverage.map { "\($0)%" } ?? "Unknown")
        
        ## Code Diff
        ```diff
        \(diff)
        ```
        
        ## Review Guidelines
        
        Please provide a comprehensive review focusing on:
        
        ### Code Quality
        - Swift best practices and conventions
        - Architecture and design patterns
        - Error handling and edge cases
        - Memory management and performance
        
        ### macOS Specific
        - Human Interface Guidelines compliance
        - Accessibility implementation
        - Dark/light mode support
        - Performance on different Mac hardware
        
        ### Security
        - Input validation
        - Data handling and privacy
        - Potential vulnerabilities
        
        ### Testing
        - Test coverage adequacy
        - Test quality and maintainability
        - Edge case coverage
        
        ## Response Format
        
        Please structure your response as:
        
        ```
        RATING: [1-10]
        RECOMMENDATION: [APPROVE|REQUEST_CHANGES|NEEDS_DISCUSSION]
        
        STRENGTHS:
        - [List positive aspects]
        
        ISSUES:
        SEVERITY: [CRITICAL|HIGH|MEDIUM|LOW]
        DESCRIPTION: [Issue description]
        LOCATION: [File and line if applicable]
        SUGGESTION: [How to fix]
        
        [Repeat ISSUES block for each issue]
        
        RECOMMENDATIONS:
        - [List improvement suggestions]
        
        DETAILED_ANALYSIS:
        [Comprehensive analysis of the changes]
        ```
        
        Focus on actionable feedback that will help improve the code quality and user experience.
        """
    }
    
    private func parseReviewResult(_ review: String) -> ReviewResult {
        let lines = review.components(separatedBy: .newlines)
        var result = ReviewResult()
        
        var currentSection = ""
        var currentIssue: ReviewIssue?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("RATING:") {
                if let rating = Int(trimmed.dropFirst(7).trimmingCharacters(in: .whitespaces)) {
                    result.overallRating = rating
                }
            } else if trimmed.hasPrefix("RECOMMENDATION:") {
                let rec = trimmed.dropFirst(15).trimmingCharacters(in: .whitespaces)
                result.recommendation = ReviewRecommendation(rawValue: rec) ?? .needsDiscussion
            } else if trimmed == "STRENGTHS:" {
                currentSection = "strengths"
            } else if trimmed == "ISSUES:" {
                currentSection = "issues"
            } else if trimmed == "RECOMMENDATIONS:" {
                currentSection = "recommendations"
            } else if trimmed.hasPrefix("SEVERITY:") {
                // Save previous issue if exists
                if let issue = currentIssue {
                    result.issues.append(issue)
                }
                
                let severity = trimmed.dropFirst(9).trimmingCharacters(in: .whitespaces)
                currentIssue = ReviewIssue(
                    severity: IssueSeverity(rawValue: severity) ?? .medium,
                    description: "",
                    location: nil,
                    suggestion: nil
                )
            } else if trimmed.hasPrefix("DESCRIPTION:") {
                currentIssue?.description = String(trimmed.dropFirst(12).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("LOCATION:") {
                currentIssue?.location = String(trimmed.dropFirst(9).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("SUGGESTION:") {
                currentIssue?.suggestion = String(trimmed.dropFirst(11).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("- ") {
                let item = String(trimmed.dropFirst(2))
                switch currentSection {
                case "strengths":
                    result.strengths.append(item)
                case "recommendations":
                    result.recommendations.append(item)
                default:
                    break
                }
            }
        }
        
        // Save last issue
        if let issue = currentIssue {
            result.issues.append(issue)
        }
        
        return result
    }
    
    private func postReviewComments(prUrl: String, review: ReviewResult, token: String) async throws {
        // This would post the review to GitHub
        // Implementation depends on GitHub API integration
        print("📝 Would post review comments to \(prUrl)")
    }
    
    private func formatAutomatedChecks(_ checks: AutomatedChecks) -> String {
        var result = ""
        result += "- **Build**: \(checks.buildPassing ? "✅ Passing" : "❌ Failing")\n"
        
        if let coverage = checks.testCoverage {
            result += "- **Test Coverage**: \(coverage)%\n"
        }
        
        if !checks.securityIssues.isEmpty {
            result += "- **Security Issues**: \(checks.securityIssues.count) found\n"
        }
        
        if !checks.performanceConcerns.isEmpty {
            result += "- **Performance Concerns**: \(checks.performanceConcerns.count) found\n"
        }
        
        return result
    }
    
    private func runCommand(_ command: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        guard process.terminationStatus == 0 else {
            throw QAReviewError.commandFailed(command, output)
        }
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Supporting Types

struct PRDetails {
    let title: String
    let author: String
    let branch: String
    let baseBranch: String
    let state: String
}

struct AutomatedChecks {
    var buildPassing = false
    var testCoverage: Double?
    var securityIssues: [String] = []
    var performanceConcerns: [String] = []
}

struct ReviewResult {
    var overallRating = 5
    var recommendation: ReviewRecommendation = .needsDiscussion
    var strengths: [String] = []
    var issues: [ReviewIssue] = []
    var recommendations: [String] = []
}

struct ReviewIssue {
    let severity: IssueSeverity
    var description: String
    var location: String?
    var suggestion: String?
}

enum ReviewRecommendation: String {
    case approve = "APPROVE"
    case requestChanges = "REQUEST_CHANGES"
    case needsDiscussion = "NEEDS_DISCUSSION"
}

enum IssueSeverity: String {
    case critical = "CRITICAL"
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
}

enum QAReviewError: Error {
    case noPRFound
    case invalidPRData
    case commandFailed(String, String)
    
    var localizedDescription: String {
        switch self {
        case .noPRFound:
            return "No PR URL found in task"
        case .invalidPRData:
            return "Could not parse PR data"
        case .commandFailed(let command, let output):
            return "Command failed: \(command)\nOutput: \(output)"
        }
    }
} 