import Foundation

class GitService {
    static let shared = GitService()
    
    private init() {}
    
    func createBranch(name: String, from baseBranch: String = "main") async throws -> String {
        let branchName = sanitizeBranchName(name)
        
        // Ensure we're on the base branch and up to date
        try await runGitCommand("git checkout \(baseBranch)")
        try await runGitCommand("git pull origin \(baseBranch)")
        
        // Create and checkout new branch
        try await runGitCommand("git checkout -b \(branchName)")
        
        return branchName
    }
    
    func commitChanges(message: String, files: [String] = []) async throws {
        // Add specific files or all changes
        if files.isEmpty {
            try await runGitCommand("git add .")
        } else {
            for file in files {
                try await runGitCommand("git add \(file)")
            }
        }
        
        // Commit with message
        try await runGitCommand("git commit -m \"\(message)\"")
    }
    
    func pushBranch(_ branchName: String) async throws {
        try await runGitCommand("git push -u origin \(branchName)")
    }
    
    func createPullRequest(
        branchName: String,
        title: String,
        description: String,
        baseBranch: String = "main"
    ) async throws -> String {
        // This would integrate with GitHub CLI or API
        let prBody = """
        ## Description
        \(description)
        
        ## Changes Made
        - Automated changes by Agent Orchestrator
        - Branch: `\(branchName)`
        - Base: `\(baseBranch)`
        
        ## QA Checklist
        - [ ] Code compiles without errors
        - [ ] Tests pass
        - [ ] UI changes reviewed
        - [ ] Performance impact assessed
        
        ## Agent Info
        - Generated: \(Date())
        - Requires human review before merge
        """
        
        let command = "gh pr create --title \"\(title)\" --body \"\(prBody)\" --base \(baseBranch)"
        let result = try await runGitCommand(command)
        
        return result
    }
    
    private func runGitCommand(_ command: String) async throws -> String {
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
            throw GitError.commandFailed(command, output)
        }
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func sanitizeBranchName(_ name: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let sanitized = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
        
        return "agent/\(sanitized)-\(timestamp)"
    }
    
    enum GitError: Error {
        case commandFailed(String, String)
        
        var localizedDescription: String {
            switch self {
            case .commandFailed(let command, let output):
                return "Git command failed: \(command)\nOutput: \(output)"
            }
        }
    }
} 