//
//  Social_BookmarkTests.swift
//  Social BookmarkTests
//
//  Created by Ünal Köseoğlu on 10.12.2025.
//

import XCTest
@testable import Social_Bookmark

final class Social_BookmarkTests: XCTestCase {

    // MARK: - Properties
    
    var mockRepository: MockBookmarkRepository!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        mockRepository = MockBookmarkRepository()
    }

    override func tearDownWithError() throws {
        mockRepository.reset()
        mockRepository = nil
    }

    // MARK: - CRUD Tests
    
    func testCreateBookmark() throws {
        // Given
        let bookmark = Bookmark(
            title: "Test Bookmark",
            url: "https://test.com",
            note: "Test note",
            source: .article
        )
        
        // When
        mockRepository.create(bookmark)
        
        // Then
        XCTAssertEqual(mockRepository.count, 1)
        XCTAssertEqual(mockRepository.createCallCount, 1)
        
        let fetched = mockRepository.fetch(by: bookmark.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.title, "Test Bookmark")
    }
    
    func testDeleteBookmark() throws {
        // Given
        mockRepository.addSampleData()
        let initialCount = mockRepository.count
        let bookmarkToDelete = mockRepository.fetchAll().first!
        
        // When
        mockRepository.delete(bookmarkToDelete)
        
        // Then
        XCTAssertEqual(mockRepository.count, initialCount - 1)
        XCTAssertNil(mockRepository.fetch(by: bookmarkToDelete.id))
    }
    
    func testFetchAllReturnsDescendingOrder() throws {
        // Given
        mockRepository.addSampleData()
        
        // When
        let bookmarks = mockRepository.fetchAll()
        
        // Then
        XCTAssertGreaterThan(bookmarks.count, 0)
        
        // Tarih sıralaması kontrolü
        for i in 0..<(bookmarks.count - 1) {
            XCTAssertGreaterThanOrEqual(
                bookmarks[i].createdAt,
                bookmarks[i + 1].createdAt,
                "Bookmarks should be sorted by date descending"
            )
        }
    }
    
    // MARK: - Search Tests
    
    func testSearchByTitle() throws {
        // Given
        mockRepository.addSampleData()
        
        // When
        let results = mockRepository.search(query: "Swift")
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Swift Tutorial")
    }
    
    func testSearchEmptyQueryReturnsAll() throws {
        // Given
        mockRepository.addSampleData()
        let totalCount = mockRepository.count
        
        // When
        let results = mockRepository.search(query: "")
        
        // Then
        XCTAssertEqual(results.count, totalCount)
    }
    
    func testSearchCaseInsensitive() throws {
        // Given
        mockRepository.addSampleData()
        
        // When
        let resultsLower = mockRepository.search(query: "swift")
        let resultsUpper = mockRepository.search(query: "SWIFT")
        
        // Then
        XCTAssertEqual(resultsLower.count, resultsUpper.count)
    }
    
    // MARK: - Filter Tests
    
    func testFilterBySource() throws {
        // Given
        mockRepository.addSampleData()
        
        // When
        let twitterPosts = mockRepository.filter(by: .twitter)
        let redditPosts = mockRepository.filter(by: .reddit)
        
        // Then
        XCTAssertEqual(twitterPosts.count, 1)
        XCTAssertEqual(redditPosts.count, 1)
        XCTAssertTrue(twitterPosts.allSatisfy { $0.source == .twitter })
    }
    
    func testFetchUnread() throws {
        // Given
        mockRepository.addSampleData()
        
        // When
        let unread = mockRepository.fetchUnread()
        
        // Then
        XCTAssertTrue(unread.allSatisfy { !$0.isRead })
    }
    
    func testFilterByTag() throws {
        // Given
        mockRepository.addSampleData()
        
        // When
        let swiftTagged = mockRepository.filter(by: "swift")
        
        // Then
        XCTAssertEqual(swiftTagged.count, 1)
        XCTAssertTrue(swiftTagged.first?.tags.contains("swift") ?? false)
    }
    
    // MARK: - Statistics Tests
    
    func testCount() throws {
        // Given
        XCTAssertEqual(mockRepository.count, 0)
        
        // When
        mockRepository.addSampleData()
        
        // Then
        XCTAssertEqual(mockRepository.count, 5)
    }
    
    func testUnreadCount() throws {
        // Given
        mockRepository.addSampleData()
        
        // When
        let unreadCount = mockRepository.unreadCount
        let totalCount = mockRepository.count
        
        // Then
        XCTAssertLessThan(unreadCount, totalCount)
        XCTAssertEqual(unreadCount, 4) // 1 tanesi isRead: true
    }
}
