import Foundation

class GitService {
    static let shared = GitService()
    private let gitQueue = DispatchQueue(label: "git-operations", qos: .userInitiated)
    
    private init() {}
    
    func createBranch(name: String, from baseBranch: String = "main") async throws -> String {
        let branchName = sanitizeBranchName(name)
        
        // Ensure we're on the base branch and up to date
        _ = try await runGitCommand("git checkout \(baseBranch)")
        _ = try await runGitCommand("git pull origin \(baseBranch)")
        
        // Create and checkout new branch
        _ = try await runGitCommand("git checkout -b \(branchName)")
        
        return branchName
    }
    
    func commitChanges(message: String, files: [String] = []) async throws {
        // Add specific files or all changes
        if files.isEmpty {
            _ = try await runGitCommand("git add .")
        } else {
            for file in files {
                _ = try await runGitCommand("git add \(file)")
            }
        }
        
        // Commit with message
        _ = try await runGitCommand("git commit -m \"\(message)\"")
    }
    
    func pushBranch(_ branchName: String) async throws {
        _ = try await runGitCommand("git push -u origin \(branchName)")
    }
    
    func createPullRequest(
        branchName: String,
        title: String,
        description: String,
        baseBranch: String = "main"
    ) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            gitQueue.async {
                do {
                    // Check if GitHub CLI is authenticated
                    let authCheckProcess = Process()
                    authCheckProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
                    authCheckProcess.arguments = ["-c", "gh auth status"]
                    
                    let authPipe = Pipe()
                    authCheckProcess.standardOutput = authPipe
                    authCheckProcess.standardError = authPipe
                    
                    try authCheckProcess.run()
                    authCheckProcess.waitUntilExit()
                    
                    if authCheckProcess.terminationStatus != 0 {
                        // GitHub CLI not authenticated, return helpful message instead of failing
                        let helpfulMessage = """
                        GitHub CLI not authenticated. To enable PR creation:
                        1. Run: gh auth login
                        2. Follow the authentication prompts
                        3. Re-run your Maestro task
                        
                        Branch '\(branchName)' has been created and pushed successfully.
                        You can manually create a PR at: https://github.com/cgcardona/Maestro/compare/\(branchName)
                        """
                        continuation.resume(returning: helpfulMessage)
                        return
                    }
                    
                    // GitHub CLI is authenticated, proceed with PR creation
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
                    let result = try self.runGitCommandSync(command)
                    
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func runGitCommandSync(_ command: String) throws -> String {
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
        
        if process.terminationStatus != 0 {
            throw GitError.commandFailed(command, output)
        }
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func runGitCommand(_ command: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            gitQueue.async {
                do {
                    let result = try self.runGitCommandSync(command)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func sanitizeBranchName(_ name: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let safeName = String(name.prefix(50))
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "^", with: "")
            .replacingOccurrences(of: "~", with: "")
            .replacingOccurrences(of: "..", with: "-")
        
        return "feature/\(safeName)-\(timestamp)"
    }
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