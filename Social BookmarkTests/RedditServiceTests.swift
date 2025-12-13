import XCTest
@testable import Social_Bookmark

final class RedditServiceTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RedditMockURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    func testFetchesAndParsesRedditPost() async throws {
        let responseJSON = """
        [{
          "data": {
            "children": [
              {"data": {
                "title": "Hello Reddit",
                "author": "swiftdev",
                "subreddit": "swift",
                "selftext": "Body text",
                "ups": 123,
                "num_comments": 45,
                "preview": {"images": [{"source": {"url": "https://i.redd.it/image.png"}}]}
              }}
            ]
          }
        }]
        """

        RedditMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(responseJSON.utf8))
        }

        let service = RedditService(session: session)
        let post = try await service.fetchPost(from: "https://reddit.com/r/swift/comments/abc/hello")

        XCTAssertEqual(post.title, "Hello Reddit")
        XCTAssertEqual(post.author, "swiftdev")
        XCTAssertEqual(post.subreddit, "swift")
        XCTAssertEqual(post.score, 123)
        XCTAssertEqual(post.commentCount, 45)
        XCTAssertEqual(post.imageURL?.absoluteString, "https://i.redd.it/image.png")
    }

    func testParsesObjectListingPayload() async throws {
        let responseJSON = """
        {
          "kind": "Listing",
          "data": {
            "children": [
              {"data": {
                "title": "Object Payload",
                "author": "reddituser",
                "subreddit": "swift",
                "selftext": "Body text",
                "ups": 77,
                "num_comments": 12,
                "thumbnail": "https://i.redd.it/image.png"
              }}
            ]
          }
        }
        """

        RedditMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(responseJSON.utf8))
        }

        let service = RedditService(session: session)
        let post = try await service.fetchPost(from: "https://reddit.com/r/swift/comments/objectpayload")

        XCTAssertEqual(post.title, "Object Payload")
        XCTAssertEqual(post.author, "reddituser")
        XCTAssertEqual(post.subreddit, "swift")
        XCTAssertEqual(post.imageURL?.absoluteString, "https://i.redd.it/image.png")
    }

    func testResolvesShortShareLinkBeforeFetchingJSON() async throws {
        let responseJSON = """
        [{
          "data": {
            "children": [
              {"data": {
                "title": "Resolved Post",
                "author": "redirected",
                "subreddit": "swift",
                "selftext": "Body text",
                "ups": 10,
                "num_comments": 2
              }}
            ]
          }
        }]
        """

        var requests: [URL] = []

        RedditMockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            requests.append(url)

            if requests.count == 1 {
                let redirectedURL = URL(string: "https://www.reddit.com/r/swift/comments/abc123")!
                let response = HTTPURLResponse(url: redirectedURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }

            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(responseJSON.utf8))
        }

        let service = RedditService(session: session)
        let post = try await service.fetchPost(from: "https://www.reddit.com/r/swift/s/shortlink")

        XCTAssertEqual(post.title, "Resolved Post")
        XCTAssertEqual(requests.first?.absoluteString, "https://www.reddit.com/r/swift/s/shortlink")
        XCTAssertTrue(requests.count >= 2)
        XCTAssertTrue(requests[1].absoluteString.contains("/r/swift/comments/abc123.json"))
    }

    func testViewModelAppliesRedditPost() async {
        let repository = PreviewMockRepository.shared
        repository.bookmarks = []

        let redditPost = RedditPost(
            title: "Swift Rocks",
            author: "iosdev",
            subreddit: "iOSProgramming",
            selfText: "Async/await tips",
            imageURL: URL(string: "https://i.redd.it/photo.png"),
            score: 900,
            commentCount: 30,
            originalURL: URL(string: "https://reddit.com/r/iOSProgramming")!
        )

        let redditMock = MockRedditService(post: redditPost)
        let viewModel = AddBookmarkViewModel(
            repository: repository,
            linkedinAuthClient: MockLinkedInAuthClient(token: nil),
            linkedinContentClient: MockLinkedInContentClient(content: LinkedInContent(title: "", summary: "", imageURL: nil, author: "")),
            linkedinHTMLParser: MockLinkedInHTMLParser(content: LinkedInContent(title: "", summary: "", imageURL: nil, author: "")),
            redditService: redditMock
        )

        viewModel.url = "https://reddit.com/r/iOSProgramming/comments/123"
        await viewModel.fetchMetadata()

        XCTAssertEqual(viewModel.selectedSource, .reddit)
        XCTAssertEqual(viewModel.fetchedRedditPost?.title, redditPost.title)
        XCTAssertEqual(viewModel.title, redditPost.title)
        XCTAssertEqual(viewModel.note, redditPost.summary)
        XCTAssertEqual(redditMock.fetchCallCount, 1)
    }
}

// MARK: - Test Doubles

final class MockRedditService: RedditPostProviding {
    let post: RedditPost
    private(set) var fetchCallCount = 0

    init(post: RedditPost) {
        self.post = post
    }

    func fetchPost(from urlString: String) async throws -> RedditPost {
        fetchCallCount += 1
        return post
    }

    func isRedditURL(_ urlString: String) -> Bool {
        urlString.contains("reddit.com")
    }
}

final class RedditMockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = RedditMockURLProtocol.requestHandler else { return }

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
