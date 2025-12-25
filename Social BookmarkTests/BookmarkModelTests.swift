//
//  BookmarkModelTests.swift
//  Social BookmarkTests
//
//  Bookmark model testleri
//

import XCTest
@testable import Social_Bookmark

final class BookmarkModelTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testBookmarkInitializationWithDefaults() {
        // When
        let bookmark = Bookmark(title: "Test")
        
        // Then
        XCTAssertEqual(bookmark.title, "Test")
        XCTAssertNil(bookmark.url)
        XCTAssertEqual(bookmark.note, "")
        XCTAssertEqual(bookmark.source, .other)
        XCTAssertFalse(bookmark.isRead)
        XCTAssertFalse(bookmark.isFavorite)
        XCTAssertNil(bookmark.categoryId)
        XCTAssertTrue(bookmark.tags.isEmpty)
        XCTAssertNil(bookmark.imageData)
        XCTAssertNil(bookmark.extractedText)
    }
    
    func testBookmarkInitializationWithAllParameters() {
        // Given
        let categoryId = UUID()
        let imageData = "test".data(using: .utf8)
        
        // When
        let bookmark = Bookmark(
            title: "Full Test",
            url: "https://test.com",
            note: "Test note",
            source: .twitter,
            isRead: true,
            isFavorite: true,
            categoryId: categoryId,
            tags: ["tag1", "tag2"],
            imageData: imageData,
            extractedText: "Extracted"
        )
        
        // Then
        XCTAssertEqual(bookmark.title, "Full Test")
        XCTAssertEqual(bookmark.url, "https://test.com")
        XCTAssertEqual(bookmark.note, "Test note")
        XCTAssertEqual(bookmark.source, .twitter)
        XCTAssertTrue(bookmark.isRead)
        XCTAssertTrue(bookmark.isFavorite)
        XCTAssertEqual(bookmark.categoryId, categoryId)
        XCTAssertEqual(bookmark.tags, ["tag1", "tag2"])
        XCTAssertEqual(bookmark.imageData, imageData)
        XCTAssertEqual(bookmark.extractedText, "Extracted")
    }
    
    // MARK: - Computed Properties Tests
    
    func testHasURL() {
        // Given
        let withURL = Bookmark(title: "Test", url: "https://test.com")
        let withoutURL = Bookmark(title: "Test")
        let withEmptyURL = Bookmark(title: "Test", url: "")
        
        // Then
        XCTAssertTrue(withURL.hasURL)
        XCTAssertFalse(withoutURL.hasURL)
        XCTAssertFalse(withEmptyURL.hasURL)
    }
    
    func testHasNote() {
        // Given
        let withNote = Bookmark(title: "Test", note: "Some note")
        let withoutNote = Bookmark(title: "Test")
        let withEmptyNote = Bookmark(title: "Test", note: "")
        
        // Then
        XCTAssertTrue(withNote.hasNote)
        XCTAssertFalse(withoutNote.hasNote)
        XCTAssertFalse(withEmptyNote.hasNote)
    }
    
    func testHasTags() {
        // Given
        let withTags = Bookmark(title: "Test", tags: ["tag1"])
        let withoutTags = Bookmark(title: "Test")
        let withEmptyTags = Bookmark(title: "Test", tags: [])
        
        // Then
        XCTAssertTrue(withTags.hasTags)
        XCTAssertFalse(withoutTags.hasTags)
        XCTAssertFalse(withEmptyTags.hasTags)
    }
    
    func testHasImage() {
        // Given
        let imageData = "test".data(using: .utf8)
        let withSingleImage = Bookmark(title: "Test", imageData: imageData)
        let withMultipleImages = Bookmark(title: "Test", imagesData: [imageData!, imageData!])
        let withoutImage = Bookmark(title: "Test")
        
        // Then
        XCTAssertTrue(withSingleImage.hasImage)
        XCTAssertTrue(withMultipleImages.hasImage)
        XCTAssertFalse(withoutImage.hasImage)
    }
    
    func testImageCount() {
        // Given
        let imageData = "test".data(using: .utf8)!
        let withSingle = Bookmark(title: "Test", imageData: imageData)
        let withMultiple = Bookmark(title: "Test", imagesData: [imageData, imageData, imageData])
        let withNone = Bookmark(title: "Test")
        
        // Then
        XCTAssertEqual(withSingle.imageCount, 1)
        XCTAssertEqual(withMultiple.imageCount, 3)
        XCTAssertEqual(withNone.imageCount, 0)
    }
    
    func testAllImagesData() {
        // Given
        let imageData = "test".data(using: .utf8)!
        let withSingle = Bookmark(title: "Test", imageData: imageData)
        let withMultiple = Bookmark(title: "Test", imagesData: [imageData, imageData])
        let withNone = Bookmark(title: "Test")
        
        // Then
        XCTAssertEqual(withSingle.allImagesData.count, 1)
        XCTAssertEqual(withMultiple.allImagesData.count, 2)
        XCTAssertEqual(withNone.allImagesData.count, 0)
    }
    
    func testHasExtractedText() {
        // Given
        let withText = Bookmark(title: "Test", extractedText: "Some text")
        let withoutText = Bookmark(title: "Test")
        let withEmptyText = Bookmark(title: "Test", extractedText: "")
        
        // Then
        XCTAssertTrue(withText.hasExtractedText)
        XCTAssertFalse(withoutText.hasExtractedText)
        XCTAssertFalse(withEmptyText.hasExtractedText)
    }
    
    // MARK: - Date Formatting Tests
    
    func testFormattedDate() {
        // Given
        let bookmark = Bookmark(title: "Test")
        
        // Then
        XCTAssertFalse(bookmark.formattedDate.isEmpty)
    }
    
    func testRelativeDate() {
        // Given
        let bookmark = Bookmark(title: "Test")
        
        // Then
        XCTAssertFalse(bookmark.relativeDate.isEmpty)
    }
}
