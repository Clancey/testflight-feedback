import Foundation
struct UpdateVariable: Encodable {

    let name: String
    let value: String
}
public final class GitHubHelper {

    // NOTE: - The endpoint considers Pull Requests to be Issues too, so we need to fetch more of them by default to ensure that one is the latest created Issue
    public static func fetchLatestIssues(labels:String,count: Int = 60, page: Int = 1, issueState: GitHubIssueState = .all) async throws -> [IssueResponse] {
        let request = URLRequest(url: try fetchLatestIssuesURL(labels:labels,count: count, page: page, issueState: issueState))
        print("Fetching tickets with request: \(request.description)", color: .cyan)
        let response: [IssueResponse] = try await GitHubNetworking.perform(dataRequest: request, decoder: .decoderWithoutMiliseconds)
        return response
            .filter(\.isIssue)
    }
    public static func fetchVariable(key:String) async throws -> String {
        let request = URLRequest(url: try fetchVariableURL(key:key))
        print("Fetching variable with request: \(request.description)", color: .cyan)
        let response: String = try await GitHubNetworking.perform(dataRequest: request, decoder: .decoderWithoutMiliseconds)
        return response
    }
     public static func updateVariable(key:String, value:String) async throws {
        let request = try URLRequest(url: try fetchVariableURL(key: key), method: .patch, body: UpdateVariable(name: key, value: value))
        try await GitHubNetworking.perform(request: request)
    }
}

public extension GitHubHelper {

    static var apiURL: URL {
        URL(string: "https://api.github.com/")!
    }

    static func repositoryURL() throws -> URL {
        var url = apiURL.appendingPathComponent("repos")
        let path = try Environment.repositoryPath.value()
        url.appendPathComponent(path)
        return url
    }

    static func issuesURL() throws -> URL {
        try repositoryURL()
            .appendingPathComponent("issues")
    }
    static func fetchVariableURL(key:String) throws -> URL {
        try repositoryURL()
            .appendingPathComponent("actions")
            .appendingPathComponent("variables")
            .appendingPathComponent(key)
    }
    /// [docu](https://docs.github.com/en/rest/issues/issues#list-repository-issues)
    static func fetchLatestIssuesURL(labels:String, count: Int = 10, page: Int = 1, issueState: GitHubIssueState = .all) throws -> URL {
        var urlComponents = URLComponents(url: try issuesURL(), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            .init(name: "state", value: "\(issueState.rawValue)"),
            .init(name: "sort", value: "created"),
            .init(name: "direction", value: "desc"),
            .init(name: "per_page", value: "\(count > 100 ? 100 : count)"),
            .init(name: "page", value: "\(page)"),
            .init(name: "labels", value: labels)
        ]
        guard let url = urlComponents.url else { throw GitHubError.badURL(message: urlComponents.description) }
        return url
    }

    static func screenshotsFolderURL() throws -> URL {
        try repositoryURL()
            .appendingPathComponent("contents")
            .appendingPathComponent("screenshots")
    }
}
