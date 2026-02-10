import XCTest
@testable import Social_Bookmark

final class OCRServiceTests: XCTestCase {
    
    func testOCRResultCleaning() {
        let rawText = """
        14:59
        99%
        ---
        John Doe
        This is a meaningful sentence that should be preserved.
        twitter.com
        @johndoe
        Done
        Next
        Another important line here.
        • A list item
        - Another list item
        """
        
        let result = OCRService.OCRResult(text: rawText, confidence: 0.9, boundingBoxes: [])
        let cleanText = result.cleanText
        
        // Assertions
        XCTAssertFalse(cleanText.contains("14:59"), "Should remove time")
        XCTAssertFalse(cleanText.contains("99%"), "Should remove battery")
        XCTAssertFalse(cleanText.contains("twitter.com"), "Should remove platform name")
        XCTAssertFalse(cleanText.contains("Done"), "Should remove UI buttons")
        XCTAssertFalse(cleanText.contains("---"), "Should remove separator-only lines")
        
        XCTAssertTrue(cleanText.contains("John Doe"), "Should preserve names")
        XCTAssertTrue(cleanText.contains("This is a meaningful sentence"), "Should preserve meaningful content")
        XCTAssertTrue(cleanText.contains("• A list item"), "Should preserve list items")
        XCTAssertTrue(cleanText.contains("\n\n"), "Should use double newlines for paragraphs")
    }
    
    func testSuggestedTitleFromPersonName() {
        let rawText = """
        Arda Güler
        Today was a great day at the office.
        I learned a lot about SwiftData.
        """
        
        let result = OCRService.OCRResult(text: rawText, confidence: 0.9, boundingBoxes: [])
        XCTAssertEqual(result.suggestedTitle, "Arda Güler")
    }
    
    func testSuggestedTitleFromMeaningfulSentence() {
        let rawText = """
        10:00
        The quick brown fox jumps over the lazy dog.
        This is another line.
        """
        
        let result = OCRService.OCRResult(text: rawText, confidence: 0.9, boundingBoxes: [])
        // Meaningful lines: "The quick brown fox..." (count > 10, words >= 2)
        XCTAssertEqual(result.suggestedTitle, "The quick brown fox jumps over the lazy dog.")
    }
    
    func testParagraphMerging() {
        let lines = [
            "This is a sentence that ends with a dot.",
            "This should be a new paragraph.",
            "This sentence continues",
            "on the next line."
        ]
        
        let rawText = lines.joined(separator: "\n")
        let result = OCRService.OCRResult(text: rawText, confidence: 0.9, boundingBoxes: [])
        let cleanText = result.cleanText
        
        let paragraphs = cleanText.components(separatedBy: "\n\n")
        XCTAssertEqual(paragraphs.count, 2)
        XCTAssertTrue(paragraphs[1].contains("This sentence continues on the next line."))
    }
}
