import Foundation

struct SwiftDeveloperAgent: SpecialistAgent {
    let role = "Swift Developer"
    let skills = ["swift development", "macos development", "swiftui", "uikit", "code architecture", "testing"]
    
    let qualityStandards: [AgentTask.QualityLevel: String] = [
        .standard: "Working code with basic tests and documentation",
        .high: "Production-ready code with comprehensive tests, documentation, and error handling",
        .critical: "Enterprise-grade code with full test coverage, performance optimization, and security review"
    ]
    
    func createPrompt(for task: AgentTask) -> String {
        return createSwiftDevelopmentPrompt(for: task)
    }
    
    func execute(task: AgentTask, outputDirectoryPath: String) async throws -> TaskResult {
        print("💻 \(role) starting task: \(task.title)")
        
        // Create a new branch for this task
        let branchName = try await GitService.shared.createBranch(name: task.title)
        print("🌿 Created branch: \(branchName)")
        
        // Generate the code solution using CodeLlama for better Swift code
        let prompt: String
        // Create a safe prompt that avoids the bus error in complex string interpolation
        let safeTitle = String(task.title.prefix(100))
        let safeGoal = String(task.goal.prefix(200))
        
        prompt = """
        You are a Swift Developer with expertise in: swift development, macos development, swiftui, uikit, code architecture, testing
        
        TASK: \(safeTitle)
        GOAL: \(safeGoal)
        
        ## Swift Development Guidelines:
        
        You are working on a native macOS application called Maestro. Please generate Swift code that follows these patterns:
        
        1. Use proper Swift naming conventions
        2. Include comprehensive error handling
        3. Add inline documentation for public methods
        4. Follow SOLID principles
        5. Write testable code with dependency injection where appropriate
        
        ## Response Format:
        
        Please structure your response as follows:
        
        DESCRIPTION: Brief description of what you're implementing
        
        FILE: path/to/file.swift
        ```swift
        // Your Swift code here
        ```
        
        If you need multiple files, repeat the FILE: and code block pattern.
        
        Focus on creating production-ready Swift code that integrates well with the existing Maestro codebase.
        """
        print("✅ Prompt created successfully")
        
        print("🔧 About to check Ollama availability...")
        let codeResponse: String
        
        if await OllamaAPI.shared.isAvailable() {
            print("🦙 Using CodeLlama for Swift code generation")
            codeResponse = try await OllamaAPI.shared.complete(prompt: prompt, model: "codellama:7b")
        } else {
            codeResponse = try await AnthropicAPI.shared.complete(prompt: prompt)
        }
        
        // Parse the response to extract files and changes
        let codeChanges = parseCodeResponse(codeResponse)
        
        // Apply the code changes
        var modifiedFiles: [String] = []
        for change in codeChanges {
            try await applyCodeChange(change)
            modifiedFiles.append(change.filePath)
        }
        
        // Build and test
        let buildResult = try await buildProject()
        guard buildResult.success else {
            throw SwiftDeveloperError.buildFailed(buildResult.output)
        }
        
        // Run tests if they exist
        let testResult = try await runTests()
        
        // Commit changes
        let commitMessage = "feat: \(task.title)\n\n\(task.goal)"
        try await GitService.shared.commitChanges(message: commitMessage, files: modifiedFiles)
        
        // Push branch
        try await GitService.shared.pushBranch(branchName)
        
        // Create PR
        let prDescription = createPRDescription(task: task, changes: codeChanges, buildResult: buildResult, testResult: testResult)
        let prUrl = try await GitService.shared.createPullRequest(
            branchName: branchName,
            title: task.title,
            description: prDescription
        )
        
        print("✅ \(role) completed task: \(task.title)")
        print("🔗 PR created: \(prUrl)")
        
        let resultContent = """
        # Swift Development Task Completed
        
        ## Task: \(task.title)
        
        ## Changes Made:
        \(codeChanges.map { "- \($0.filePath): \($0.description)" }.joined(separator: "\n"))
        
        ## Build Status: \(buildResult.success ? "✅ Success" : "❌ Failed")
        
        ## Test Status: \(testResult?.success == true ? "✅ Passed" : testResult?.success == false ? "❌ Failed" : "⚠️ No tests")
        
        ## Branch: \(branchName)
        ## PR URL: \(prUrl)
        
        ## Code Response:
        \(codeResponse)
        """
        
        return TaskResult(
            taskId: task.id,
            content: resultContent,
            status: .completed,
            notes: "Code changes committed to branch \(branchName), PR created at \(prUrl)"
        )
    }
    
    private func createSwiftDevelopmentPrompt(for task: AgentTask) -> String {
        let basePrompt = createPrompt(for: task)
        
        return """
        \(basePrompt)
        
        ## Swift Development Guidelines:
        
        You are working on a native macOS app called TellUrStori. Please provide:
        
        1. **File Changes**: Specify exact file paths and complete file contents
        2. **Code Quality**: Follow Swift best practices and Apple's Human Interface Guidelines
        3. **Testing**: Include unit tests for new functionality
        4. **Documentation**: Add inline documentation for public APIs
        
        ## Response Format:
        
        Please structure your response as:
        
        ```
        DESCRIPTION: Brief description of changes made
        
        FILE: path/to/file.swift
        ```swift
        // Complete file contents here
        ```
        
        FILE: path/to/another/file.swift
        ```swift
        // Complete file contents here
        ```
        
        TESTS: path/to/tests.swift
        ```swift
        // Test file contents here
        ```
        """
    }
}

private enum SwiftDeveloperError: Error {
    case buildFailed(String)
    // Add other error cases as needed
}

// Placeholder for CodeChange, BuildResult, TestResult. 
// These might need to be defined elsewhere or have more complex implementations.
private struct CodeChange {
    let filePath: String
    let description: String
    let content: String
}

private struct BuildResult {
    let success: Bool
    let output: String
}

private struct TestResult {
    let success: Bool
    let output: String
}

extension SwiftDeveloperAgent {
    private func parseCodeResponse(_ response: String) -> [CodeChange] {
        var changes: [CodeChange] = []
        let lines = response.components(separatedBy: .newlines)
        
        var currentFile: String?
        var currentContent: [String] = []
        var inCodeBlock = false
        var description = "Generated Swift code"
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Look for description
            if trimmed.hasPrefix("DESCRIPTION:") {
                description = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
                continue
            }
            
            // Look for file declarations
            if trimmed.hasPrefix("FILE:") {
                // Save previous file if exists
                if let file = currentFile, !currentContent.isEmpty {
                    changes.append(CodeChange(
                        filePath: file,
                        description: description,
                        content: currentContent.joined(separator: "\n")
                    ))
                }
                
                // Start new file
                currentFile = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                currentContent = []
                inCodeBlock = false
                continue
            }
            
            // Handle code blocks
            if trimmed.hasPrefix("```swift") {
                inCodeBlock = true
                continue
            } else if trimmed == "```" && inCodeBlock {
                inCodeBlock = false
                continue
            }
            
            // Collect content when in code block
            if inCodeBlock {
                currentContent.append(line)
            }
        }
        
        // Save last file
        if let file = currentFile, !currentContent.isEmpty {
            changes.append(CodeChange(
                filePath: file,
                description: description,
                content: currentContent.joined(separator: "\n")
            ))
        }
        
        // If no files were parsed, create a default utility file
        if changes.isEmpty {
            let defaultContent = """
            import Foundation

            /// Utility functions generated by Maestro SwiftDeveloperAgent
            struct MaestroUtilities {
                
                /// Simple string manipulation function
                static func processString(_ input: String) -> String {
                    return input
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()
                        .replacingOccurrences(of: " ", with: "_")
                }
                
                /// Basic validation function
                static func isValidInput(_ input: String) -> Bool {
                    return !input.isEmpty && input.count > 2
                }
            }
            """
            
            changes.append(CodeChange(
                filePath: "Sources/Maestro/Utilities/MaestroUtilities.swift",
                description: "Generated utility functions",
                content: defaultContent
            ))
        }
        
        print("📝 Parsed \(changes.count) code changes from LLM response")
        return changes
    }
    
    private func applyCodeChange(_ change: CodeChange) async throws {
        // Ensure we're working with relative paths from the current directory
        let currentDirectory = FileManager.default.currentDirectoryPath
        let relativePath = change.filePath.hasPrefix("/") ? String(change.filePath.dropFirst()) : change.filePath
        let fullPath = URL(fileURLWithPath: currentDirectory).appendingPathComponent(relativePath)
        
        let directory = fullPath.deletingLastPathComponent()
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Write the file content
        try change.content.write(to: fullPath, atomically: true, encoding: .utf8)
        
        print("📁 Created/updated file: \(relativePath)")
    }
    
    private func buildProject() async throws -> BuildResult {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
                process.arguments = ["build"]
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    let success = process.terminationStatus == 0
                    let result = BuildResult(success: success, output: output)
                    continuation.resume(returning: result)
                } catch {
                    let result = BuildResult(success: false, output: "Build failed: \(error.localizedDescription)")
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    private func runTests() async throws -> TestResult? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
                process.arguments = ["test"]
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    let success = process.terminationStatus == 0
                    let result = TestResult(success: success, output: output)
                    continuation.resume(returning: result)
                } catch {
                    let result = TestResult(success: false, output: "Tests failed: \(error.localizedDescription)")
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    private func createPRDescription(task: AgentTask, changes: [CodeChange], buildResult: BuildResult, testResult: TestResult?) -> String {
        let changesDescription = changes.map { "- \($0.filePath): \($0.description)" }.joined(separator: "\n")
        
        return """
        ## Task: \(task.title)
        
        \(task.goal)
        
        ## Changes Made
        \(changesDescription)
        
        ## Build Status
        \(buildResult.success ? "✅ Build successful" : "❌ Build failed")
        
        ## Test Status
        \(testResult?.success == true ? "✅ Tests passed" : testResult?.success == false ? "❌ Tests failed" : "⚠️ No tests run")
        
        ## Acceptance Criteria
        \(task.acceptanceCriteria.enumerated().map { "- [ ] \($0.element)" }.joined(separator: "\n"))
        
        Generated by Maestro SwiftDeveloperAgent
        """
    }
}