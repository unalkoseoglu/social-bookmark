import PDFKit
import UIKit

/// PDF dosyalarından metin çıkarma ve işlem yapma servisi
final class PDFService {
    // MARK: - Singleton
    
    static let shared = PDFService()
    private init() {}
    
    // MARK: - Models
    
    struct PDFExtractionResult {
        let text: String
        let pageCount: Int
        let isEncrypted: Bool
        let hasTextContent: Bool
        
        /// Temizlenmiş ve formatlanmış metin
        var cleanText: String {
            text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        /// Başlık önerisi (ilk satır veya dosya adından türetilmeli)
        var suggestedTitle: String? {
            let lines = cleanText.components(separatedBy: "\n")
            if let firstLine = lines.first, firstLine.count > 5, firstLine.count < 100 {
                return firstLine.trimmingCharacters(in: .whitespaces)
            }
            return nil
        }
    }
    
    // MARK: - Public Methods
    
    /// PDF dosyasından metin çıkar
    /// - Parameter url: PDF dosyasının yerel URL'i
    /// - Returns: PDFExtractionResult
    func extractText(from url: URL) async throws -> PDFExtractionResult {
        guard let document = PDFDocument(url: url) else {
            throw PDFError.invalidDocument
        }
        
        let isEncrypted = document.isEncrypted
        let pageCount = document.pageCount
        var fullText = ""
        
        for i in 0..<pageCount {
            if let page = document.page(at: i), let pageContent = page.string {
                fullText += pageContent + "\n"
            }
        }
        
        let hasTextContent = !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        return PDFExtractionResult(
            text: fullText,
            pageCount: pageCount,
            isEncrypted: isEncrypted,
            hasTextContent: hasTextContent
        )
    }
    
    /// PDF'i görsellere dönüştür (OCR için gerekirse)
    func convertPDFToImages(from url: URL, maxPages: Int = 3) async throws -> [UIImage] {
        guard let document = PDFDocument(url: url) else {
            throw PDFError.invalidDocument
        }
        
        var images: [UIImage] = []
        let actualMaxPages = min(document.pageCount, maxPages)
        
        for i in 0..<actualMaxPages {
            if let page = document.page(at: i) {
                let pageRect = page.bounds(for: .mediaBox)
                let renderer = UIGraphicsImageRenderer(size: pageRect.size)
                
                let image = renderer.image { context in
                    UIColor.white.set()
                    context.fill(pageRect)
                    context.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                    context.cgContext.scaleBy(x: 1.0, y: -1.0)
                    
                    page.draw(with: .mediaBox, to: context.cgContext)
                }
                images.append(image)
            }
        }
        
        return images
    }
}

// MARK: - Error Types

enum PDFError: LocalizedError {
    case invalidDocument
    case extractionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidDocument:
            return "Geçersiz PDF dokümanı"
        case .extractionFailed:
            return "PDF metni çıkarılamadı"
        }
    }
}
