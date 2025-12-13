import XCTest
@testable import Social_Bookmark

final class LinkedInIntegrationTests: XCTestCase {
    private var session: URLSession!
    private var tokenStore: InMemoryLinkedInTokenStore!

    override func setUp() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
        tokenStore = InMemoryLinkedInTokenStore()
    }

    func testAuthClientDecodesToken() async throws {
        let expectedBody = "{\"access_token\":\"abc123\",\"refresh_token\":\"refresh\",\"expires_in\":3600}"
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(url: URL(string: "https://www.linkedin.com/oauth/v2/accessToken")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, expectedBody.data(using: .utf8)!)
        }

        let config = LinkedInConfig(
            clientID: "client",
            clientSecret: "secret",
            redirectURI: "app://callback"
        )

        let authClient = LinkedInAuthClient(config: config, session: session, tokenStore: tokenStore)
        let token = try await authClient.exchangeAuthorizationCode("code")

        XCTAssertEqual(token.accessToken, "abc123")
        XCTAssertEqual(token.refreshToken, "refresh")
        XCTAssertNotNil(tokenStore.storedToken)
    }

    func testContentClientParsesResponse() async throws {
        let contentJSON = """
        {"author":"urn:li:person:123","lifecycleState":"PUBLISHED","specificContent":{"shareContent":{"shareCommentary":{"text":"Hello LinkedIn"},"shareMediaCategory":"ARTICLE","media":[{"originalUrl":"https://images.example.com/photo.jpg"}]}}}
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(contentJSON.utf8))
        }

        let contentClient = LinkedInContentClient(session: session)
        let token = LinkedInAccessToken(accessToken: "abc", refreshToken: nil, expiresAt: nil)
        let content = try await contentClient.fetchContent(
            from: URL(string: "https://www.linkedin.com/posts/123")!,
            token: token
        )

        XCTAssertEqual(content.title, "Hello LinkedIn")
        XCTAssertEqual(content.author, "urn:li:person:123")
        XCTAssertEqual(content.imageURL?.absoluteString, "https://images.example.com/photo.jpg")
    }

    func testViewModelFetchesLinkedInContent() async throws {
        let repository = PreviewMockRepository.shared
        repository.bookmarks = []

        let token = LinkedInAccessToken(accessToken: "abc", refreshToken: nil, expiresAt: nil)
        let authMock = MockLinkedInAuthClient(token: token)
        let contentMock = MockLinkedInContentClient(
            content: LinkedInContent(
                title: "LinkedIn Post",
                summary: "Summary",
                imageURL: nil,
                author: "urn:li:person:1"
            )
        )

        let viewModel = AddBookmarkViewModel(
            repository: repository,
            linkedinAuthClient: authMock,
            linkedinContentClient: contentMock
        )

        viewModel.url = "https://www.linkedin.com/posts/example"
        await viewModel.fetchMetadata()

        XCTAssertEqual(viewModel.selectedSource, .linkedin)
        XCTAssertEqual(viewModel.fetchedLinkedInContent?.title, "LinkedIn Post")
    }

    func testLinkedInUrlDetection() {
        let repository = PreviewMockRepository.shared
        let viewModel = AddBookmarkViewModel(repository: repository)

        XCTAssertTrue(viewModel.isLinkedInURL("https://www.linkedin.com/posts/example"))
        XCTAssertTrue(viewModel.isLinkedInURL("https://www.linkedin.com/company/example"))
        XCTAssertFalse(viewModel.isLinkedInURL("https://www.example.com"))
    }
}

// MARK: - Test Doubles

final class InMemoryLinkedInTokenStore: LinkedInTokenStore {
    private(set) var storedToken: LinkedInAccessToken?

    override func save(_ token: LinkedInAccessToken) throws {
        storedToken = token
    }

    override func load() -> LinkedInAccessToken? {
        storedToken
    }

    override func clear() {
        storedToken = nil
    }
}

final class MockLinkedInAuthClient: LinkedInAuthProviding {
    var token: LinkedInAccessToken?

    init(token: LinkedInAccessToken?) {
        self.token = token
    }

    func cachedToken() -> LinkedInAccessToken? { token }

    func store(token: LinkedInAccessToken) throws {
        self.token = token
    }

    func ensureValidToken() async throws -> LinkedInAccessToken {
        guard let token else { throw LinkedInError.authorizationRequired }
        return token
    }
}

final class MockLinkedInContentClient: LinkedInContentProviding {
    let content: LinkedInContent

    init(content: LinkedInContent) {
        self.content = content
    }

    func fetchContent(from url: URL, token: LinkedInAccessToken) async throws -> LinkedInContent {
        content
    }
}

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: LinkedInError.networkError)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
