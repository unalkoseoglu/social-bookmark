//
//  TwitterServiceTests.swift
//  Social BookmarkTests
//
//  TwitterService testleri
//

import XCTest
@testable import Social_Bookmark

final class TwitterServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    var service: TwitterService!
    
    // MARK: - Setup
    
    override func setUpWithError() throws {
        service = TwitterService.shared
    }
    
    // MARK: - URL Detection Tests
    
    func testIsTwitterURL_ValidTwitterDotCom() {
        // Given
        let url = "https://twitter.com/user/status/123456789"
        
        // When
        let result = service.isTwitterURL(url)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testIsTwitterURL_ValidXDotCom() {
        // Given
        let url = "https://x.com/user/status/123456789"
        
        // When
        let result = service.isTwitterURL(url)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testIsTwitterURL_WithWWW() {
        // Given
        let url = "https://www.twitter.com/user/status/123"
        
        // When
        let result = service.isTwitterURL(url)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testIsTwitterURL_InvalidURL() {
        // Given
        let urls = [
            "https://facebook.com/post",
            "https://reddit.com/r/swift",
            "https://example.com",
            ""
        ]
        
        // When & Then
        for url in urls {
            XCTAssertFalse(service.isTwitterURL(url), "Should be false for: \(url)")
        }
    }
    
    func testIsTwitterURL_CaseInsensitive() {
        // Given
        let urls = [
            "https://TWITTER.COM/user/status/123",
            "https://Twitter.Com/user/status/123",
            "https://X.COM/user/status/123"
        ]
        
        // When & Then
        for url in urls {
            XCTAssertTrue(service.isTwitterURL(url), "Should be true for: \(url)")
        }
    }
    
    func testIsTwitterURL_MobileURL() {
        // Given
        let url = "https://mobile.twitter.com/user/status/123"
        
        // When
        let result = service.isTwitterURL(url)
        
        // Then
        XCTAssertTrue(result)
    }
    
    // MARK: - Tweet Model Tests
    
    func testTweetShortSummary_UnderLimit() {
        // Given
        let tweet = createTestTweet(text: "Short tweet text")
        
        // Then
        XCTAssertEqual(tweet.shortSummary, "Short tweet text")
    }
    
    func testTweetShortSummary_OverLimit() {
        // Given
        let longText = String(repeating: "a", count: 100)
        let tweet = createTestTweet(text: longText)
        
        // Then
        XCTAssertTrue(tweet.shortSummary.count <= 83) // 80 + "..."
        XCTAssertTrue(tweet.shortSummary.hasSuffix("..."))
    }
    
    func testTweetShortSummary_RemovesNewlines() {
        // Given
        let textWithNewlines = "First line\nSecond line\nThird line"
        let tweet = createTestTweet(text: textWithNewlines)
        
        // Then
        XCTAssertFalse(tweet.shortSummary.contains("\n"))
    }
    
    func testTweetHasMedia_WithMedia() {
        // Given
        let tweet = createTestTweet(
            text: "Test",
            mediaURLs: [URL(string: "https://example.com/image.jpg")!]
        )
        
        // Then
        XCTAssertTrue(tweet.hasMedia)
    }
    
    func testTweetHasMedia_WithoutMedia() {
        // Given
        let tweet = createTestTweet(text: "Test", mediaURLs: [])
        
        // Then
        XCTAssertFalse(tweet.hasMedia)
    }
    
    func testTweetFirstImageURL() {
        // Given
        let imageURLs = [
            URL(string: "https://example.com/first.jpg")!,
            URL(string: "https://example.com/second.jpg")!
        ]
        let tweet = createTestTweet(text: "Test", mediaURLs: imageURLs)
        
        // Then
        XCTAssertEqual(tweet.firstImageURL?.absoluteString, "https://example.com/first.jpg")
    }
    
    func testTweetFullText() {
        // Given
        let tweet = createTestTweet(
            text: "Hello World!",
            authorName: "Test User",
            authorUsername: "testuser"
        )
        
        // Then
        XCTAssertTrue(tweet.fullText.contains("@testuser"))
        XCTAssertTrue(tweet.fullText.contains("Test User"))
        XCTAssertTrue(tweet.fullText.contains("Hello World!"))
    }
    
    // MARK: - Helper Methods
    
    private func createTestTweet(
        text: String,
        authorName: String = "Test User",
        authorUsername: String = "testuser",
        mediaURLs: [URL] = []
    ) -> TwitterService.Tweet {
        return TwitterService.Tweet(
            id: "123456789",
            text: text,
            authorName: authorName,
            authorUsername: authorUsername,
            authorAvatarURL: nil,
            mediaURLs: mediaURLs,
            createdAt: nil,
            likeCount: 10,
            retweetCount: 5,
            replyCount: 2,
            originalURL: URL(string: "https://twitter.com/testuser/status/123456789")!
        )
    }
}
