import Foundation
import Utils

public func runScript() {
    Task.detached {
        var lastInsertedCrashTimestamp: Date?
        var lastInsertedScreenshotTimestamp: Date?
        var shouldUpdateTimestamps = true
        do {
            try await SpaceAuth.refreshAuth()
            var feedbacks = try await FeedbackRepository.getFeedbacks()
            let lastTicketTimestamp = try await GitHubRepository.getLastScreenshotTimestamp()
            let newFeedbacks = feedbacks.newer(than: lastTicketTimestamp)
            print("Successfully fetched \(newFeedbacks.count) new feedback \(newFeedbacks.count > 0 ? "🤩" : "😭")", color: .green, bold: true)
            if !newFeedbacks.isEmpty {
                let githubRepo = try await GitHubRepository()

                for feedback in newFeedbacks.reversed() {
                    try await githubRepo.setupIssue(feedback: feedback)
                    lastInsertedScreenshotTimestamp = feedback.attributes.timestamp
                }
            }

            let lastCrashTimestamp = try await GitHubRepository.getLastCrashTimestamp()
            feedbacks = try await FeedbackRepository.getCrashes()
            let newCrashes = feedbacks.newer(than: lastCrashTimestamp)
            print("Successfully fetched \(newCrashes.count) new crashes \(newCrashes.count > 0 ? "🤩" : "😭")", color: .green, bold: true)
            if !newCrashes.isEmpty {
                
                let githubRepo = try await GitHubRepository()
                for feedback in newCrashes.reversed() {
                    try await githubRepo.setupCrash(feedback: feedback)
                    lastInsertedCrashTimestamp = feedback.attributes.timestamp
                }
            }

            shouldUpdateTimestamps = false;
            do{
                try await updateTimeStamps(lastInsertedCrashTimestamp: lastInsertedCrashTimestamp, lastInsertedScreenshotTimestamp: lastInsertedScreenshotTimestamp)
            }
            catch{
                print("Failed to update timestamps: \(error)", color: .red)
            }
            exit(EXIT_SUCCESS)
        } catch {
            printFailedJob(error)
            if shouldUpdateTimestamps {
                do{
                    try await updateTimeStamps(lastInsertedCrashTimestamp: lastInsertedCrashTimestamp, lastInsertedScreenshotTimestamp: lastInsertedScreenshotTimestamp)
                }
                catch{
                    print("Failed to update timestamps: \(error)", color: .red)
                }
            }
            exit(EXIT_FAILURE)
        }
    }

    RunLoop.current.run()
}
func updateTimeStamps(lastInsertedCrashTimestamp: Date?, lastInsertedScreenshotTimestamp: Date?) async throws {
    if let lastInsertedCrashTimestamp = lastInsertedCrashTimestamp {
        print("Updating last crash timestamp: \(lastInsertedCrashTimestamp)")
        try await GitHubHelper.updateVariable(key: "LAST_CRASH_TIMESTAMP", value: DateFormatter.iso8601.string(from: lastInsertedCrashTimestamp))
    }
    if let lastInsertedScreenshotTimestamp = lastInsertedScreenshotTimestamp {
        print("Updating last crash timestamp: \(lastInsertedCrashTimestamp)")
        try await GitHubHelper.updateVariable(key: "LAST_SCREENSHOT_TIMESTAMP", value: DateFormatter.iso8601.string(from: lastInsertedScreenshotTimestamp))
    }
}
