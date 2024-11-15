import Foundation
import Utils

final class GitHubRepository {

    private var milestones: [Milestone] = []

    init() async throws {
        milestones = try await fetchMilestones()
    }

    // MARK: - Static Methods

    static func getLastScreenshotTimestamp() async throws -> Date? {
        do {
            let dateString = try await GitHubHelper.fetchVariable(key: "LAST_SCREENSHOT_TIMESTAMP")
            let lastCrashTimestamp = DateFormatter.iso8601.date(from: dateString)
            print("Last crash timestamp: \(lastCrashTimestamp?.description ?? "nil")")
            return lastCrashTimestamp
        } catch {
            print("Error getting last screenshot timestamp: \(error)")
            print("Using issues to get last crash timestamp")
            let tickets = try await GitHubHelper.fetchLatestIssues(labels: "Feedback")

            //IF no tickets return min date
            if tickets.isEmpty {
                return Date(timeIntervalSince1970: 0)
            }

            let lastTicketTimestamp =
                tickets
                .compactMap(\.appStoreConnectCreationDate)
                .max()

            if let date = lastTicketTimestamp {
                print([
                    .init(text: "Last screenshot is based on feedback from: ", color: .cyan),
                    .init(
                        text: DateFormatter.readable.string(from: date), color: .cyan, bold: true),
                ])
            }
            return lastTicketTimestamp
        }
    }
    static var tickets: [IssueResponse] = []
    static func getLastCrashTimestamp() async throws -> Date? {
        do {
            let dateString = try await GitHubHelper.fetchVariable(key: "LAST_CRASH_TIMESTAMP")
            let lastCrashTimestamp = DateFormatter.iso8601.date(from: dateString)
            print("Last crash timestamp: \(lastCrashTimestamp?.description ?? "nil")")
            return lastCrashTimestamp
        } catch {
            print("Error getting last crash timestamp: \(error)")
            print("Using issues to get last crash timestamp")
            let tickets = try await GitHubHelper.fetchLatestIssues(labels: "Crash Report")
            //IF no tickets return min date
            if tickets.isEmpty {
                return Date(timeIntervalSince1970: 0)
            }

            let lastTicketTimestamp =
                tickets
                .compactMap(\.appStoreConnectCreationDate)
                .max()

            if let date = lastTicketTimestamp {
                print([
                    .init(text: "Last crash is based on feedback from: ", color: .cyan),
                    .init(
                        text: DateFormatter.readable.string(from: date), color: .cyan, bold: true),
                ])
            }
            return lastTicketTimestamp
        }
    }

    // MARK: - Issues

    /// - creates milestone if required, otherwise reuses existing one
    /// - adds screenshots to repository if present
    /// - creates an issue from feedback
    /// - adds the issue to backlog column
    func setupIssue(feedback: Feedback) async throws {
        let milestone = try await dequeueMilestone(title: feedback.appVersionString)
        var screenshots: [ImageReference] = []
        do{ screenshots = try await addScreenshotsToRepository(
            feedback.screenshotURLs,
            timestamp: feedback.attributes.timestamp)
        } catch {
            print("Screenshot already uploaded. Skipping Duplicate")
            return;
        }
        let issue = try Issue(
            from: feedback, milestoneNumber: milestone.number, screenshots: screenshots)
        let githubIssue = try await createIssue(issue)
        if let backlogColumnIdString = try? Environment.backlogColumnId.value(),
            let backlogColumnId = Int(backlogColumnIdString)
        {
            let card = try await add(issue: githubIssue, to: backlogColumnId)
            print("Project card created successfully: \(card)", color: .green)
        }
    }
    func setupCrash(feedback: Feedback) async throws {
        let milestone = try await dequeueMilestone(title: feedback.appVersionString)
        let issue = try Issue(from: feedback, milestoneNumber: milestone.number)
        let githubIssue = try await createIssue(issue)
        if let backlogColumnIdString = try? Environment.backlogColumnId.value(),
            let backlogColumnId = Int(backlogColumnIdString)
        {
            let card = try await add(issue: githubIssue, to: backlogColumnId)
            print("Project card created successfully: \(card)", color: .green)
        }
    }

    private func createIssue(_ issue: Issue) async throws -> IssueResponseModel {
        let request = try URLRequest(url: try GitHubHelper.issuesURL(), method: .post, body: issue)

        print([
            .init(text: "Creating ticket: ", color: .yellow),
            .init(text: issue.title, color: .yellow, bold: true),
        ])

        return try await GitHubNetworking.perform(dataRequest: request)
    }

    // MARK: - Milestones

    private func dequeueMilestone(title: String) async throws -> Milestone {
        if let milestone = milestones.first(where: { $0.title == title }) {
            return milestone
        } else {
            print("Milestone Creating: \(title)", color: .green)
            let milestone = try await createMilestone(title)
            print("Milestone created successfully: \(milestone)", color: .green)
            milestones.append(milestone)
            return milestone
        }
    }

    private func createMilestone(_ title: String) async throws -> Milestone {
        let milestone = Milestone(number: nil, title: title)
        let request = try URLRequest(url: try milestonesURL(), method: .post, body: milestone)

        print([
            .init(text: "Creating milestone: ", color: .yellow),
            .init(text: title, color: .yellow, bold: true),
        ])

        return try await GitHubNetworking.perform(
            dataRequest: request, decoder: .decoderWithoutMiliseconds)
    }

    private func fetchMilestones() async throws -> [Milestone] {
        print("Fetching milestones..", color: .yellow)
        let request = URLRequest(url: try milestonesURL())
        return try await GitHubNetworking.perform(
            dataRequest: request, decoder: .decoderWithoutMiliseconds)
    }

    // MARK: - Project / Board

    /// [docu](https://developer.github.com/v3/projects/cards/#create-a-project-card)
    private func add(issue: IssueResponseModel, to columnId: Int) async throws -> ProjectCard {
        let issueCard = ProjectIssueCard(issueId: issue.id)
        let url = projectColumnCardURL(columnId: columnId)
        let request = try URLRequest(url: url, method: .post, body: issueCard)

        print("Adding issue to board: \(issue)", color: .yellow)

        return try await GitHubNetworking.perform(dataRequest: request)
    }

    // MARK: - Screenshots

    private func addScreenshotsToRepository(_ screenshots: [ImageReference], timestamp: Date)
        async throws -> [ImageReference]
    {
        var uploadedScreenshots: [ImageReference] = []
        for enumeration in screenshots.enumerated() {
            let fileName = "\(DateFormatter.iso8601.string(from: timestamp))_\(enumeration.offset)"
            let uploadedThumbnailURL = try await uploadScreenshotToRepository(
                enumeration.element.thumbnailURL, fileName: fileName + "-thumbnail")
            let uploadedScreenshotURL = try await uploadScreenshotToRepository(
                enumeration.element.url, fileName: fileName)
            uploadedScreenshots.append(
                .init(thumbnailURL: uploadedThumbnailURL, url: uploadedScreenshotURL))
        }
        return uploadedScreenshots
    }

    private func uploadScreenshotToRepository(_ imageURL: URL, fileName: String) async throws -> URL
    {
        let (imageData, _) = try await URLSession.shared.data(for: URLRequest(url: imageURL))
        let body = RepositoryContentBody(
            message: "Adding screenshot \(fileName)",
            content: imageData.base64EncodedString())
        let request = try URLRequest(
            url: try GitHubHelper.screenshotsFolderURL().appendingPathComponent(fileName + ".jpg"),
            method: .put, body: body)
        let response: RepositoryContentResponseModel = try await GitHubNetworking.perform(
            dataRequest: request)
        var components = URLComponents(
            url: response.content.html_url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "raw", value: "true")
        ]
        return components.url!
    }
}

extension GitHubRepository {

    fileprivate func projectColumnCardURL(columnId: Int) -> URL {
        GitHubHelper.apiURL.appendingPathComponent("projects/columns/\(columnId)/cards")
    }

    fileprivate func milestonesURL() throws -> URL {
        var urlComponents = URLComponents(
            url: try GitHubHelper.repositoryURL().appendingPathComponent("milestones"),
            resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            .init(name: "sort", value: "completeness"),
            .init(name: "per_page", value: "100"),
        ]
        guard let url = urlComponents.url else {
            throw GitHubError.badURL(message: urlComponents.description)
        }
        return url
    }
}
