import Foundation

struct QAReviewAgent: SpecialistAgent {
    let role = "QA Review Specialist"
    let skills = ["code review", "quality assurance", "testing", "security review", "performance analysis", "pr review"]
    
    let qualityStandards: [AgentTask.QualityLevel: String] = [
        .standard: "Basic code review focusing on functionality and obvious issues",
        .high: "Comprehensive review including performance, security, and maintainability",
        .critical: "Exhaustive review with security audit, performance profiling, and architectural assessment"
    ]
    
    func execute(task: AgentTask, outputDirectoryPath: String) async throws -> TaskResult {
        print("🔍 \(role) starting review: \(task.title)")
        
        // Try to find PR URL in task, or discover recent PRs
        let prUrl: String
        if let extractedUrl = extractPRUrl(from: task) {
            prUrl = extractedUrl
        } else {
            // Look for recent PRs that might need review
            prUrl = try await findRecentPRForReview()
        }
        
        // Get PR details and diff
        let prDetails = try await getPRDetails(prUrl)
        let diffContent = try await getPRDiff(prUrl)
        
        // Perform automated checks
        let automatedChecks = try await runAutomatedChecks(prUrl)
        
        // Generate AI review using Ollama if available, fallback to Anthropic
        let reviewPrompt = createReviewPrompt(task: task, prDetails: prDetails, diff: diffContent, automatedChecks: automatedChecks)
        let aiReview: String
        
        if await OllamaAPI.shared.isAvailable() {
            print("🦙 Using Ollama for code review analysis")
            aiReview = try await OllamaAPI.shared.complete(prompt: reviewPrompt, model: "llama3.2:3b")
        } else {
            aiReview = try await AnthropicAPI.shared.complete(prompt: reviewPrompt)
        }
        
        // Parse review and create feedback
        let reviewResult = parseReviewResult(aiReview)
        
        // Post review comments to GitHub
        try await postReviewToGitHub(prUrl: prUrl, review: reviewResult)
        
        // Create action items based on review
        let actionItems = createActionItems(prDetails: prDetails, review: reviewResult, prUrl: prUrl)
        
        print("✅ \(role) completed review: \(task.title)")
        print("📋 Created \(actionItems.count) action items for human review")
        
        let resultContent = """
        # QA Review Report
        
        ## PR: \(prDetails.title)
        **URL**: \(prUrl)
        **Author**: \(prDetails.author)
        **Branch**: \(prDetails.branch) → \(prDetails.baseBranch)
        **Status**: \(prDetails.state)
        
        ## Automated Checks
        \(formatAutomatedChecks(automatedChecks))
        
        ## AI Review Summary
        **Overall Rating**: \(reviewResult.overallRating)/10
        **Recommendation**: \(reviewResult.recommendation.rawValue)
        
        ### Strengths
        \(reviewResult.strengths.map { "- \($0)" }.joined(separator: "\n"))
        
        ### Issues Found (\(reviewResult.issues.count))
        \(reviewResult.issues.map { "- **\($0.severity.rawValue)**: \($0.description)" }.joined(separator: "\n"))
        
        ### Recommendations (\(reviewResult.recommendations.count))
        \(reviewResult.recommendations.map { "- \($0)" }.joined(separator: "\n"))
        
        ## Action Items for Human Review
        \(actionItems.map { "- \($0)" }.joined(separator: "\n"))
        
        ## Next Steps
        \(getNextSteps(for: reviewResult.recommendation, rating: reviewResult.overallRating))
        
        ## Detailed Review
        \(aiReview)
        """
        
        return TaskResult(
            taskId: task.id,
            content: resultContent,
            status: .completed,
            notes: "QA review completed for PR \(prUrl) with rating \(reviewResult.overallRating)/10 - \(reviewResult.recommendation.rawValue)"
        )
    }
    
    private func findRecentPRForReview() async throws -> String {
        // Find the most recent open PR that hasn't been reviewed yet
        let command = "gh pr list --state open --limit 5 --json number,title,author,createdAt"
        let output = try await runCommand(command)
        
        guard let data = output.data(using: .utf8),
              let prs = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let firstPR = prs.first,
              let prNumber = firstPR["number"] as? Int else {
            throw QAReviewError.noPRFound
        }
        
        return "https://github.com/cgcardona/Maestro/pull/\(prNumber)"
    }
    
    private func extractPRUrl(from task: AgentTask) -> String? {
        // Look for PR URL in task resources, goal, or notes
        let text = "\(task.goal) \(task.resources.joined(separator: " "))"
        let pattern = #"https://github\.com/[^/]+/[^/]+/pull/\d+"#
        
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range])
        }
        
        return nil
    }
    
    private func getPRDetails(_ prUrl: String) async throws -> PRDetails {
        // Extract PR number from URL
        let prNumber = prUrl.components(separatedBy: "/").last ?? ""
        
        // Use GitHub CLI to get PR details
        let command = "gh pr view \(prNumber) --json title,author,headRefName,baseRefName,state,createdAt,updatedAt"
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
            state: json["state"] as? String ?? "",
            createdAt: json["createdAt"] as? String ?? "",
            updatedAt: json["updatedAt"] as? String ?? ""
        )
    }
    
    private func getPRDiff(_ prUrl: String) async throws -> String {
        let prNumber = prUrl.components(separatedBy: "/").last ?? ""
        let command = "gh pr diff \(prNumber)"
        return try await runCommand(command)
    }
    
    private func runAutomatedChecks(_ prUrl: String) async throws -> AutomatedChecks {
        let prNumber = prUrl.components(separatedBy: "/").last ?? ""
        var checks = AutomatedChecks()
        
        // Check CI/CD status
        do {
            let checksCommand = "gh pr checks \(prNumber) --json state,conclusion,name"
            let checksOutput = try await runCommand(checksCommand)
            
            if let data = checksOutput.data(using: .utf8),
               let checksJson = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                
                let passedChecks = checksJson.filter { ($0["conclusion"] as? String) == "success" }
                let failedChecks = checksJson.filter { ($0["conclusion"] as? String) == "failure" }
                
                checks.buildPassing = failedChecks.isEmpty && !passedChecks.isEmpty
                checks.ciChecks = checksJson.map { $0["name"] as? String ?? "Unknown" }
            }
        } catch {
            print("⚠️ Could not fetch CI checks: \(error)")
            checks.buildPassing = false
        }
        
        // Analyze diff for potential issues
        let diff = try await getPRDiff(prUrl)
        checks.securityIssues = analyzeSecurityIssues(in: diff)
        checks.performanceConcerns = analyzePerformanceConcerns(in: diff)
        checks.codeQualityIssues = analyzeCodeQuality(in: diff)
        
        return checks
    }
    
    private func analyzeSecurityIssues(in diff: String) -> [String] {
        var issues: [String] = []
        
        // Check for common security anti-patterns
        if diff.contains("ProcessInfo.processInfo.environment") {
            issues.append("Environment variable access detected - ensure sensitive data is handled securely")
        }
        
        if diff.contains("UserDefaults") && diff.contains("password") {
            issues.append("Potential password storage in UserDefaults - consider using Keychain")
        }
        
        if diff.contains("http://") {
            issues.append("HTTP URLs detected - ensure HTTPS is used for sensitive data")
        }
        
        return issues
    }
    
    private func analyzePerformanceConcerns(in diff: String) -> [String] {
        var concerns: [String] = []
        
        // Check for potential performance issues
        if diff.contains("for ") && diff.contains("await ") {
            concerns.append("Potential serial async operations in loop - consider using TaskGroup for concurrency")
        }
        
        if diff.contains("JSONSerialization") && diff.contains("large") {
            concerns.append("Large JSON processing detected - consider streaming or chunked processing")
        }
        
        if diff.contains("Timer") && diff.contains("0.") {
            concerns.append("High-frequency timer detected - verify performance impact")
        }
        
        return concerns
    }
    
    private func analyzeCodeQuality(in diff: String) -> [String] {
        var issues: [String] = []
        
        // Check for code quality issues
        if diff.contains("// TODO") || diff.contains("// FIXME") {
            issues.append("TODO/FIXME comments found - ensure they are addressed before merging")
        }
        
        if diff.contains("print(") && !diff.contains("DEBUG") {
            issues.append("Print statements detected - consider using proper logging")
        }
        
        if diff.contains("force unwrap") || diff.contains("!") {
            issues.append("Force unwrapping detected - ensure safe unwrapping patterns")
        }
        
        return issues
    }
    
    private func postReviewToGitHub(prUrl: String, review: ReviewResult) async throws {
        let prNumber = prUrl.components(separatedBy: "/").last ?? ""
        
        // Create review summary
        let reviewBody = """
        ## 🤖 Automated QA Review
        
        **Overall Rating**: \(review.overallRating)/10
        **Recommendation**: \(review.recommendation.getEmoji()) \(review.recommendation.rawValue)
        
        ### ✅ Strengths
        \(review.strengths.map { "- \($0)" }.joined(separator: "\n"))
        
        ### ⚠️ Issues Found
        \(review.issues.map { "- **\($0.severity.rawValue)**: \($0.description)" }.joined(separator: "\n"))
        
        ### 💡 Recommendations
        \(review.recommendations.map { "- \($0)" }.joined(separator: "\n"))
        
        ---
        *This review was generated by Maestro QA Agent. Please address any critical or high-severity issues before merging.*
        """
        
        // Post review comment
        let command = "gh pr comment \(prNumber) --body \"\(reviewBody.replacingOccurrences(of: "\"", with: "\\\""))\""
        
        do {
            _ = try await runCommand(command)
            print("📝 Posted automated review to PR #\(prNumber)")
        } catch {
            print("⚠️ Could not post review comment: \(error)")
        }
    }
    
    private func createActionItems(prDetails: PRDetails, review: ReviewResult, prUrl: String) -> [String] {
        var actionItems: [String] = []
        
        // Create action items based on review results
        switch review.recommendation {
        case .approve:
            if review.overallRating >= 8 {
                actionItems.append("✅ **READY TO MERGE**: PR \(prDetails.title) - High quality code, approved for merge")
            } else {
                actionItems.append("✅ **APPROVED WITH MINOR NOTES**: PR \(prDetails.title) - Consider addressing minor recommendations")
            }
            
        case .requestChanges:
            actionItems.append("🔄 **CHANGES REQUIRED**: PR \(prDetails.title) - Address critical/high severity issues before merge")
            
            // Add specific action items for critical issues
            let criticalIssues = review.issues.filter { $0.severity == .critical }
            for issue in criticalIssues {
                actionItems.append("🚨 **CRITICAL**: \(issue.description)")
            }
            
        case .needsDiscussion:
            actionItems.append("💬 **NEEDS DISCUSSION**: PR \(prDetails.title) - Complex changes require human review")
        }
        
        // Add action item for PR URL
        actionItems.append("🔗 **Review PR**: \(prUrl)")
        
        return actionItems
    }
    
    private func getNextSteps(for recommendation: ReviewRecommendation, rating: Int) -> String {
        switch recommendation {
        case .approve:
            return rating >= 8 ? 
                "✅ This PR is ready to merge. No blocking issues found." :
                "✅ This PR can be merged after considering the minor recommendations."
                
        case .requestChanges:
            return "🔄 Please address the identified issues, particularly any critical or high-severity items, before merging."
            
        case .needsDiscussion:
            return "💬 This PR contains complex changes that would benefit from human review and discussion before proceeding."
        }
    }
    
    private func createReviewPrompt(task: AgentTask, prDetails: PRDetails, diff: String, automatedChecks: AutomatedChecks) -> String {
        return """
        You are a senior QA engineer reviewing a Pull Request for Maestro, an AI-powered agent orchestrator written in Swift.
        
        ## PR Details
        - **Title**: \(prDetails.title)
        - **Author**: \(prDetails.author)
        - **Branch**: \(prDetails.branch) → \(prDetails.baseBranch)
        - **Quality Level**: \(task.qualityLevel.rawValue)
        
        ## Automated Checks
        - Build Status: \(automatedChecks.buildPassing ? "✅ Passing" : "❌ Failing")
        - CI Checks: \(automatedChecks.ciChecks.isEmpty ? "None" : automatedChecks.ciChecks.joined(separator: ", "))
        - Security Issues: \(automatedChecks.securityIssues.count) found
        - Performance Concerns: \(automatedChecks.performanceConcerns.count) found
        - Code Quality Issues: \(automatedChecks.codeQualityIssues.count) found
        
        ## Code Diff
        ```diff
        \(diff.prefix(2000))
        ```
        
        ## Review Guidelines for Maestro
        
        Focus on these areas specific to the Maestro AI orchestrator:
        
        ### Swift Code Quality
        - Swift best practices and modern concurrency (async/await)
        - Proper error handling and Result types
        - Memory management and retain cycles
        - Protocol-oriented design patterns
        
        ### AI Integration
        - Ollama API integration patterns
        - Prompt engineering quality
        - AI response parsing robustness
        - Fallback mechanisms for AI services
        
        ### Agent Architecture
        - Specialist agent implementations
        - Task orchestration patterns
        - Concurrent task execution safety
        - Agent skill matching accuracy
        
        ### Git/GitHub Integration
        - Git workflow automation
        - GitHub CLI integration
        - Branch naming and commit message quality
        - PR creation and management
        
        ### Testing & Reliability
        - Unit test coverage and quality
        - Error recovery mechanisms
        - Concurrency safety
        - Integration test scenarios
        
        ## Response Format
        
        Structure your response exactly as follows:
        
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
    
    private func formatAutomatedChecks(_ checks: AutomatedChecks) -> String {
        var result = ""
        result += "- **Build**: \(checks.buildPassing ? "✅ Passing" : "❌ Failing")\n"
        
        if !checks.ciChecks.isEmpty {
            result += "- **CI Checks**: \(checks.ciChecks.joined(separator: ", "))\n"
        }
        
        if !checks.securityIssues.isEmpty {
            result += "- **Security Issues** (\(checks.securityIssues.count)):\n"
            for issue in checks.securityIssues {
                result += "  - \(issue)\n"
            }
        }
        
        if !checks.performanceConcerns.isEmpty {
            result += "- **Performance Concerns** (\(checks.performanceConcerns.count)):\n"
            for concern in checks.performanceConcerns {
                result += "  - \(concern)\n"
            }
        }
        
        if !checks.codeQualityIssues.isEmpty {
            result += "- **Code Quality Issues** (\(checks.codeQualityIssues.count)):\n"
            for issue in checks.codeQualityIssues {
                result += "  - \(issue)\n"
            }
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
    let createdAt: String
    let updatedAt: String
}

struct AutomatedChecks {
    var buildPassing = false
    var securityIssues: [String] = []
    var performanceConcerns: [String] = []
    var ciChecks: [String] = []
    var codeQualityIssues: [String] = []
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
    
    func getEmoji() -> String {
        switch self {
        case .approve:
            return "✅"
        case .requestChanges:
            return "🔄"
        case .needsDiscussion:
            return "💬"
        }
    }
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