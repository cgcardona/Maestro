import Foundation

struct DocumentationAgent: SpecialistAgent {
    let role = "Documentation Specialist"
    let skills = ["technical writing", "documentation", "api documentation", "user guides", "markdown", "content creation"]
    
    let qualityStandards: [AgentTask.QualityLevel: String] = [
        .standard: "Clear, well-structured documentation with basic examples",
        .high: "Comprehensive documentation with examples, diagrams, and cross-references",
        .critical: "Enterprise-grade documentation with full coverage, interactive examples, and accessibility compliance"
    ]
    
    func execute(task: AgentTask, outputDirectoryPath: String) async throws -> TaskResult {
        print("📚 \(role) starting task: \(task.title)")
        
        let prompt = createDocumentationPrompt(for: task)
        let response = try await AnthropicAPI.shared.complete(prompt: prompt)
        
        // Parse response to extract documentation files
        let docFiles = parseDocumentationResponse(response)
        var createdFileFullPaths: [String] = [] // To store full paths for TaskResult
        
        // Create documentation files
        for docFile in docFiles {
            // Pass outputDirectoryPath to createDocumentationFile
            let fullPath = try await createDocumentationFile(docFile, outputDirectoryPath: outputDirectoryPath)
            createdFileFullPaths.append(fullPath)
        }
        
        print("✅ \(role) completed task: \(task.title)")
        
        // Use createdFileFullPaths for the TaskResult
        let filesCreatedMarkdown = createdFileFullPaths.enumerated().map { (index, fullPath) -> String in
            // Assuming docFiles and createdFileFullPaths are in the same order
            // and docFiles[index] corresponds to the file at fullPath.
            // Ensure that accessing docFiles[index] is safe, or use a more robust mapping if order isn't guaranteed.
            let description = docFiles[index].description
            return "- \(fullPath) (Description: \(description))"
        }.joined(separator: "\n")

        let resultContent = """
        # Documentation Task Completed
        
        ## Task: \(task.title)
        
        ## Files Created:
        \(filesCreatedMarkdown)
        
        ## Documentation Response:
        \(response)
        """
        
        return TaskResult(
            taskId: task.id,
            content: resultContent,
            status: .completed,
            notes: "Created \(createdFileFullPaths.count) documentation files: \(createdFileFullPaths.joined(separator: ", "))",
            generatedFiles: createdFileFullPaths // Populate with full paths
        )
    }
    
    private func createDocumentationPrompt(for task: AgentTask) -> String {
        let basePrompt = createPrompt(for: task)
        
        return """
        \(basePrompt)
        
        ## Documentation Guidelines:
        
        You are creating documentation for TellUrStori, a native macOS storytelling app. Please provide:
        
        1. **Clear Structure**: Use proper headings, sections, and navigation
        2. **Code Examples**: Include Swift code examples where relevant
        3. **User-Focused**: Write for both developers and end users as appropriate
        4. **Markdown Format**: Use proper markdown syntax
        5. **Accessibility**: Ensure documentation is accessible and well-organized
        
        ## Response Format:
        
        Please structure your response as:
        
        ```
        DESCRIPTION: Brief description of documentation created
        
        FILE: path/to/documentation.md
        DESCRIPTION: Purpose of this documentation file
        ```markdown
        # Documentation content here
        ```
        
        FILE: path/to/another-doc.md
        DESCRIPTION: Purpose of this documentation file
        ```markdown
        # More documentation content
        ```
        ```
        
        ## TellUrStori Context:
        - Native macOS app for storytelling
        - Uses SwiftUI for modern UI
        - Follows MVVM architecture
        - Supports multimedia storytelling
        - Focus on user experience and accessibility
        
        Please create comprehensive, well-structured documentation that helps users and developers.
        """
    }
    
    private func parseDocumentationResponse(_ response: String) -> [DocumentationFile] {
        var files: [DocumentationFile] = []
        let lines = response.components(separatedBy: .newlines)
        
        var currentFileRelativePath: String? // Store the relative path from AI
        var currentDescription: String?
        var currentContent: [String] = []
        var inCodeBlock = false
        
        for line in lines {
            if line.hasPrefix("FILE:") {
                // Save previous file if exists
                if let filePath = currentFileRelativePath, let description = currentDescription, !currentContent.isEmpty {
                    files.append(DocumentationFile(
                        path: filePath, // This is the relative path like docs/MyFeature.md
                        content: currentContent.joined(separator: "\n"),
                        description: description
                    ))
                }
                
                currentFileRelativePath = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                currentContent = []
                currentDescription = nil
                inCodeBlock = false
            } else if line.hasPrefix("DESCRIPTION:") && currentFileRelativePath != nil {
                currentDescription = String(line.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("```markdown") {
                inCodeBlock = true
            } else if line.hasPrefix("```") && inCodeBlock {
                inCodeBlock = false
            } else if inCodeBlock {
                currentContent.append(line)
            }
        }
        
        // Save last file
        if let filePath = currentFileRelativePath, let description = currentDescription, !currentContent.isEmpty {
            files.append(DocumentationFile(
                path: filePath, // This is the relative path
                content: currentContent.joined(separator: "\n"),
                description: description
            ))
        }
        
        return files
    }
    
    // Modified to accept outputDirectoryPath and return the full path of the created file
    private func createDocumentationFile(_ docFile: DocumentationFile, outputDirectoryPath: String) async throws -> String {
        // docFile.path is the relative path from AI, e.g., "manuals/user-guide.md" or "feature.md"
        let relativeFilePath = docFile.path
        
        // Construct the full destination path
        let fullDestPath = URL(fileURLWithPath: outputDirectoryPath).appendingPathComponent(relativeFilePath).path
        
        let url = URL(fileURLWithPath: fullDestPath)
        
        // Create intermediate directories if they are part of relativeFilePath
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        
        // Write the documentation file
        try docFile.content.write(to: url, atomically: true, encoding: .utf8)
        print("📝 Created documentation: \(fullDestPath)")
        return fullDestPath // Return the full path where the file was saved
    }
}

struct DocumentationFile {
    let path: String // This will store the relative path from the AI response
    let content: String
    let description: String
} 