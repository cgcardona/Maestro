import Foundation

print("🚀 Agent Orchestrator MVP Starting")

// Check if we have a standup file argument
let arguments = CommandLine.arguments
if arguments.count > 1 {
    let standupFile = arguments[1]
    
    do {
        // Load and execute tasks from standup file
        let manager = ManagerAgent.shared
        let tasks = try await manager.loadTasksFromStandup(standupFile)
        
        print("📋 Loaded \(tasks.count) tasks from \(standupFile)")
        print("🎯 Starting task execution...")
        
        let summary = try await manager.executeAllTasks()
        
        print("\n🎉 Execution Complete!")
        print("✅ Success: \(summary.successCount)/\(summary.totalTasks)")
        print("❌ Failed: \(summary.failureCount)/\(summary.totalTasks)")
        print("⏱️ Duration: \(String(format: "%.2f", summary.duration)) seconds")
        
    } catch {
        print("❌ Error: \(error.localizedDescription)")
        exit(1)
    }
    
} else {
    // Run single test task for demo
    print("🧪 Running single test task (no standup file provided)")
    
    let testTask = AgentTask(
        title: "Competitive Analysis Research",
        goal: "Understand how TellUrStori compares to similar platforms to identify strategic opportunities",
        acceptanceCriteria: [
            "Analysis of 3-5 competitor platforms with feature matrices",
            "Feature gap identification with impact assessment",
            "Unique value proposition clarification and positioning strategy"
        ],
        complexity: .simple,
        qualityLevel: .standard,
        skillsNeeded: ["market research", "competitive analysis", "strategic thinking"],
        resources: ["Competitor websites", "industry reports", "feature comparison tools"],
        testingRequirements: "Validate competitor information accuracy",
        documentationRequirements: "Competitive analysis report with recommendations",
        successIndicators: ["Clear understanding of competitive landscape and positioning"]
    )
    
    do {
        let manager = ManagerAgent.shared
        let result = try await manager.executeTask(testTask)
        
        print("\n📊 Task Completed!")
        print("📝 Result Preview:")
        print(String(result.content.prefix(200)) + "...")
        
        // Save result to file
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "test-result-\(timestamp).txt"
        try result.content.write(toFile: filename, atomically: true, encoding: .utf8)
        print("💾 Full result saved to: \(filename)")
        
    } catch {
        print("❌ Task failed: \(error.localizedDescription)")
        exit(1)
    }
    
    print("\n💡 To run with a standup file:")
    print("swift run Maestro path/to/standup-file.md")
} 