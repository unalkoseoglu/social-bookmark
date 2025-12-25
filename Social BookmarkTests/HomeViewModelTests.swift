//
//  HomeViewModelTests.swift
//  Social BookmarkTests
//
//  HomeViewModel testleri
//

import XCTest
@testable import Social_Bookmark

final class HomeViewModelTests: XCTestCase {
    
    // MARK: - Properties
    
    var mockBookmarkRepo: MockBookmarkRepository!
    var mockCategoryRepo: MockCategoryRepository!
    var viewModel: HomeViewModel!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        mockBookmarkRepo = MockBookmarkRepository()
        mockCategoryRepo = MockCategoryRepository()
        viewModel = HomeViewModel(
            bookmarkRepository: mockBookmarkRepo,
            categoryRepository: mockCategoryRepo
        )
    }
    
    override func tearDownWithError() throws {
        mockBookmarkRepo.reset()
        mockCategoryRepo.reset()
        viewModel = nil
    }
    
    // MARK: - Computed Properties Tests
    
    func testTotalCount() {
        // Given
        XCTAssertEqual(viewModel.totalCount, 0)
        
        // When
        mockBookmarkRepo.addSampleData()
        
        // Then
        XCTAssertEqual(viewModel.totalCount, 5)
    }
    
    func testUnreadCount() {
        // Given
        mockBookmarkRepo.addSampleData()
        
        // When
        let unreadCount = viewModel.unreadCount
        
        // Then
        XCTAssertEqual(unreadCount, 4) // 1 tanesi read
    }
    
    func testAllBookmarks() {
        // Given
        mockBookmarkRepo.addSampleData()
        
        // When
        let bookmarks = viewModel.allBookmarks
        
        // Then
        XCTAssertEqual(bookmarks.count, 5)
    }
    
    func testRecentBookmarks() {
        // Given
        mockBookmarkRepo.addSampleData()
        
        // When
        let recent = viewModel.recentBookmarks
        
        // Then
        XCTAssertLessThanOrEqual(recent.count, 10)
    }
    
    // MARK: - Search Tests
    
    func testSearch() {
        // Given
        mockBookmarkRepo.addSampleData()
        
        // When
        let results = viewModel.search(query: "Swift")
        
        // Then
        XCTAssertEqual(results.count, 1)
    }
    
    func testSearchEmptyReturnsAll() {
        // Given
        mockBookmarkRepo.addSampleData()
        
        // When
        let results = viewModel.search(query: "")
        
        // Then
        XCTAssertEqual(results.count, 5)
    }
    
    // MARK: - Bookmark Actions Tests
    
    func testToggleReadStatus() {
        // Given
        let bookmark = Bookmark(title: "Test", isRead: false)
        mockBookmarkRepo.create(bookmark)
        
        // When
        viewModel.toggleReadStatus(bookmark)
        
        // Then
        XCTAssertTrue(bookmark.isRead)
        XCTAssertEqual(mockBookmarkRepo.updateCallCount, 1)
    }
    
    func testToggleFavorite() {
        // Given
        let bookmark = Bookmark(title: "Test", isFavorite: false)
        mockBookmarkRepo.create(bookmark)
        
        // When
        viewModel.toggleFavorite(bookmark)
        
        // Then
        XCTAssertTrue(bookmark.isFavorite)
        XCTAssertEqual(mockBookmarkRepo.updateCallCount, 1)
    }
    
    func testDeleteBookmark() {
        // Given
        mockBookmarkRepo.addSampleData()
        let initialCount = mockBookmarkRepo.count
        let bookmarkToDelete = mockBookmarkRepo.fetchAll().first!
        
        // When
        viewModel.deleteBookmark(bookmarkToDelete)
        
        // Then
        XCTAssertEqual(mockBookmarkRepo.count, initialCount - 1)
        XCTAssertEqual(mockBookmarkRepo.deleteCallCount, 1)
    }
    
    // MARK: - Category Tests
    
    func testAddCategory() async {
        // Given
        let category = Category(name: "Test Category")
        
        // When
        await viewModel.addCategory(category)
        
        // Then
        XCTAssertEqual(mockCategoryRepo.createCallCount, 1)
    }
    
    func testDeleteCategory() {
        // Given
        let category = Category(name: "Test Category")
        mockCategoryRepo.create(category)
        
        // When
        viewModel.deleteCategory(category)
        
        // Then
        XCTAssertEqual(mockCategoryRepo.deleteCallCount, 1)
    }
    
    func testBookmarkCountForCategory() {
        // Given
        let category = Category(name: "Test")
        let bookmark = Bookmark(title: "Test", categoryId: category.id)
        mockCategoryRepo.create(category)
        mockBookmarkRepo.create(bookmark)
        
        // When
        let count = viewModel.bookmarkCount(for: category)
        
        // Then
        XCTAssertEqual(count, 1)
    }
}
