//
//  BookmarkSourceTests.swift
//  Social BookmarkTests
//
//  BookmarkSource enum testleri
//

import XCTest
@testable import Social_Bookmark

final class BookmarkSourceTests: XCTestCase {
    
    // MARK: - URL Detection Tests
    
    func testDetectTwitterURL() {
        // Given
        let twitterURLs = [
            "https://twitter.com/user/status/123",
            "https://x.com/user/status/123",
            "https://www.twitter.com/post"
        ]
        
        // When & Then
        for url in twitterURLs {
            let detected = BookmarkSource.detect(from: url)
            XCTAssertEqual(detected, .twitter, "Failed for URL: \(url)")
        }
    }
    
    func testDetectRedditURL() {
        // Given
        let redditURLs = [
            "https://reddit.com/r/swift/comments/123",
            "https://www.reddit.com/r/ios",
            "https://old.reddit.com/r/programming"
        ]
        
        // When & Then
        for url in redditURLs {
            let detected = BookmarkSource.detect(from: url)
            XCTAssertEqual(detected, .reddit, "Failed for URL: \(url)")
        }
    }
    
    func testDetectLinkedInURL() {
        // Given
        let linkedInURLs = [
            "https://linkedin.com/posts/user",
            "https://www.linkedin.com/feed/update/123",
            "https://linkedin.com/in/profile"
        ]
        
        // When & Then
        for url in linkedInURLs {
            let detected = BookmarkSource.detect(from: url)
            XCTAssertEqual(detected, .linkedin, "Failed for URL: \(url)")
        }
    }
    
    func testDetectMediumURL() {
        // Given
        let mediumURLs = [
            "https://medium.com/@user/article",
            "https://medium.com/publication/article"
        ]
        
        // When & Then
        for url in mediumURLs {
            let detected = BookmarkSource.detect(from: url)
            XCTAssertEqual(detected, .medium, "Failed for URL: \(url)")
        }
    }
    
    func testDetectYouTubeURL() {
        // Given
        let youtubeURLs = [
            "https://youtube.com/watch?v=123",
            "https://www.youtube.com/watch?v=abc",
            "https://youtu.be/123"
        ]
        
        // When & Then
        for url in youtubeURLs {
            let detected = BookmarkSource.detect(from: url)
            XCTAssertEqual(detected, .youtube, "Failed for URL: \(url)")
        }
    }
    
    func testDetectGitHubURL() {
        // Given
        let githubURLs = [
            "https://github.com/user/repo",
            "https://www.github.com/org/project"
        ]
        
        // When & Then
        for url in githubURLs {
            let detected = BookmarkSource.detect(from: url)
            XCTAssertEqual(detected, .github, "Failed for URL: \(url)")
        }
    }
    
    func testDetectUnknownURLReturnsOther() {
        // Given
        let unknownURLs = [
            "https://example.com/page",
            "https://random-site.org",
            ""
        ]
        
        // When & Then
        for url in unknownURLs {
            let detected = BookmarkSource.detect(from: url)
            XCTAssertEqual(detected, .other, "Failed for URL: \(url)")
        }
    }
    
    // MARK: - Display Properties Tests
    
    func testDisplayNameNotEmpty() {
        // When & Then
        for source in BookmarkSource.allCases {
            XCTAssertFalse(source.displayName.isEmpty, "displayName empty for: \(source)")
        }
    }
    
    func testEmojiNotEmpty() {
        // When & Then
        for source in BookmarkSource.allCases {
            XCTAssertFalse(source.emoji.isEmpty, "emoji empty for: \(source)")
        }
    }
    
    func testSystemIconNotEmpty() {
        // When & Then
        for source in BookmarkSource.allCases {
            XCTAssertFalse(source.systemIcon.isEmpty, "systemIcon empty for: \(source)")
        }
    }
    
    // MARK: - Identifiable Tests
    
    func testIdIsRawValue() {
        // When & Then
        for source in BookmarkSource.allCases {
            XCTAssertEqual(source.id, source.rawValue)
        }
    }
    
    // MARK: - All Cases Tests
    
    func testAllCasesCount() {
        // Then
        XCTAssertEqual(BookmarkSource.allCases.count, 9)
    }
}
