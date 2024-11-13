import Foundation
import Utils

public func runScript() {
    Task.detached {
        do {
            let feedbacks = try await FeedbackRepository.getFeedbacks()
            let lastTicketTimestamp = try await GitHubRepository.getLastScreenshotTimestamp()
            let newFeedbacks = feedbacks.newer(than: lastTicketTimestamp)
            print("Successfully fetched \(newFeedbacks.count) new feedback \(newFeedbacks.count > 0 ? "🤩" : "😭")", color: .green, bold: true)
            if !newFeedbacks.isEmpty {
                let githubRepo = try await GitHubRepository()

                for feedback in newFeedbacks.reversed() {
                    try await githubRepo.setupIssue(feedback: feedback)
                }
            }

            let lastCrashTimestamp = try await GitHubRepository.getLastCrashTimestamp()
            let newCrashes = feedbacks.newer(than: lastCrashTimestamp)
            print("Successfully fetched \(newCrashes.count) new crashes \(newCrashes.count > 0 ? "🤩" : "😭")", color: .green, bold: true)
            if !newCrashes.isEmpty {
                let githubRepo = try await GitHubRepository()

                for feedback in newCrashes.reversed() {
                    try await githubRepo.setupIssue(feedback: feedback)
                }
            }

            exit(EXIT_SUCCESS)
        } catch {
            printFailedJob(error)
            exit(EXIT_FAILURE)
        }
    }

    RunLoop.current.run()
}
