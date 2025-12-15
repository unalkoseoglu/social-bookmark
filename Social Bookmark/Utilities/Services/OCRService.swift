import Vision
import UIKit

/// OCR (Optical Character Recognition) servisi
/// Fotoğraflardan metin çıkarır - Apple Vision Framework kullanır
final class OCRService {
    // MARK: - Singleton
    
    static let shared = OCRService()
    private init() {}
    
    // MARK: - Models
    
    struct OCRResult {
        let text: String
        let confidence: Float
        let boundingBoxes: [CGRect]
        
        /// Temiz metin - formatlanmış ve gereksiz bilgiler filtrelenmiş
        var cleanText: String {
            let cleaned = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n\n\n", with: "\n\n") // Fazla satır atlama
            
            return smartClean(cleaned)
        }
        
        /// Akıllı başlık çıkarımı - en anlamlı başlığı bul
        var suggestedTitle: String? {
            let lines = cleanText.components(separatedBy: "\n")
            
            // 1. Kişi ismi algıla (Büyük Harf + Büyük Harf formatı)
            if let personName = detectPersonName(in: lines) {
                return personName
            }
            
            // 2. En anlamlı cümleyi bul
            let meaningfulLines = lines.filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                // Saat formatı atla
                if trimmed.range(of: "^\\d{1,2}:\\d{2}$", options: .regularExpression) != nil {
                    return false
                }
                
                // En az 15 karakter
                guard trimmed.count >= 15 else { return false }
                // En fazla 100 karakter (başlık için uygun)
                guard trimmed.count <= 100 else { return false }
                // En az 3 kelime
                guard trimmed.split(separator: " ").count >= 3 else { return false }
                // Nokta ile bitiyorsa çok uzun olabilir, atla
                if trimmed.hasSuffix(".") && trimmed.count > 60 {
                    return false
                }
                return true
            }
            
            // İlk anlamlı satırı döndür
            if let firstMeaningful = meaningfulLines.first {
                return truncateTitle(firstMeaningful)
            }
            
            // 3. Fallback: İlk satırın ilk 60 karakteri (saat değilse)
            if let firstLine = lines.first {
                let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
                if trimmed.range(of: "^\\d{1,2}:\\d{2}$", options: .regularExpression) == nil {
                    return truncateTitle(firstLine)
                }
            }
            
            return nil
        }
        
        /// Kişi ismi algılama - "Ad Soyad" formatı
        private func detectPersonName(in lines: [String]) -> String? {
            for line in lines.prefix(3) { // İlk 3 satıra bak
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                // İki kelime kontrolü
                let words = trimmed.split(separator: " ")
                guard words.count == 2 || words.count == 3 else { continue }
                
                // Her kelime büyük harfle başlamalı
                let allCapitalized = words.allSatisfy { word in
                    guard let firstChar = word.first else { return false }
                    return firstChar.isUppercase
                }
                
                guard allCapitalized else { continue }
                
                // Çok uzun değilse (muhtemelen isim değil)
                guard trimmed.count <= 50 else { continue }
                
                // Sayı içermemeli
                guard !trimmed.contains(where: { $0.isNumber }) else { continue }
                
                // Geçerli isim formatı
                return trimmed
            }
            
            return nil
        }
        
        /// Başlığı kısalt - maksimum 80 karakter
        private func truncateTitle(_ text: String) -> String {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            
            if trimmed.count <= 80 {
                return trimmed
            }
            
            // Kelime sınırında kes
            let words = trimmed.split(separator: " ")
            var result = ""
            
            for word in words {
                let testString = result.isEmpty ? String(word) : result + " " + String(word)
                if testString.count > 75 {
                    break
                }
                result = testString
            }
            
            return result + "..."
        }
        
        /// Akıllı temizleme - gereksiz UI elementlerini filtrele
        private func smartClean(_ text: String) -> String {
            let lines = text.components(separatedBy: "\n")
            var cleanedLines: [String] = []
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                // Boş satırları atla
                guard !trimmed.isEmpty else { continue }
                
                // Tek karakter veya sadece noktalama işaretleri olan satırları atla
                if trimmed.count <= 2 && trimmed.rangeOfCharacter(from: .letters) == nil {
                    continue
                }
                
                // Saat formatı (14:59, 02:10, vb.) - atla
                if trimmed.range(of: "^\\d{1,2}:\\d{2}$", options: .regularExpression) != nil {
                    continue
                }
                
                // Batarya yüzdesi (99%, 100%, vb.) - atla
                if trimmed.range(of: "^\\d{1,3}%?'?$", options: .regularExpression) != nil {
                    continue
                }
                
                // Tek nokta, üç nokta, tire gibi karakterler - atla
                if trimmed.range(of: "^[\\.\\-…•]+$", options: .regularExpression) != nil {
                    continue
                }
                
                // Screenshot, Text Content gibi UI başlıkları - atla
                let uiLabels = ["screenshot", "text content", "open", "copy", "share", "notlar", "etiketler"]
                if uiLabels.contains(where: { trimmed.lowercased() == $0 }) {
                    continue
                }
                
                // Sosyal medya platform isimleri (X.com, Twitter.com) - atla
                if trimmed.lowercased().contains(".com") && trimmed.count < 15 {
                    continue
                }
                
                // Twitter handle (@username) tek başına ise atla
                if trimmed.hasPrefix("@") && !trimmed.contains(" ") {
                    continue
                }
                
                // Sadece emoji olan satırları atla
                if trimmed.unicodeScalars.allSatisfy({ $0.properties.isEmoji }) {
                    continue
                }
                
                // Geçerli satır - ekle
                cleanedLines.append(trimmed)
            }
            
            // Satırları akıllıca birleştir
            return mergeLines(cleanedLines)
        }
        
        /// Satır sonlarını akıllıca birleştir - doğal paragraf akışı sağla
        private func mergeLines(_ lines: [String]) -> String {
            guard !lines.isEmpty else { return "" }
            
            var merged: [String] = []
            var currentParagraph = ""
            
            for (_, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                // İlk satır
                if currentParagraph.isEmpty {
                    currentParagraph = trimmed
                    continue
                }
                
                // Önceki satır cümle sonu ile bitiyorsa (. ! ?) - yeni paragraf başlat
                let lastChar = currentParagraph.last
                if lastChar == "." || lastChar == "!" || lastChar == "?" {
                    merged.append(currentParagraph)
                    currentParagraph = trimmed
                    continue
                }
                
                // Satır büyük harfle başlıyorsa VE önceki satır kısa değilse - yeni paragraf
                if let firstChar = trimmed.first, firstChar.isUppercase,
                   currentParagraph.count > 40,
                   lastChar != "," {
                    merged.append(currentParagraph)
                    currentParagraph = trimmed
                    continue
                }
                
                // Satır sayı ile başlıyorsa (liste) - yeni satır
                if trimmed.range(of: "^\\d+[\\.)\\-]", options: .regularExpression) != nil {
                    merged.append(currentParagraph)
                    currentParagraph = trimmed
                    continue
                }
                
                // Satır tire ile başlıyorsa (madde) - yeni satır
                if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") {
                    merged.append(currentParagraph)
                    currentParagraph = trimmed
                    continue
                }
                
                // Tek kelime veya çok kısa satır - önceki satıra ekle
                if trimmed.split(separator: " ").count <= 2 {
                    currentParagraph += " " + trimmed
                    continue
                }
                
                // Normal durum: önceki satıra boşlukla ekle
                currentParagraph += " " + trimmed
            }
            
            // Son paragrafı ekle
            if !currentParagraph.isEmpty {
                merged.append(currentParagraph)
            }
            
            return merged.joined(separator: "\n\n")
        }
    }
    
    // MARK: - Public Methods
    
    /// Resimden metin çıkar
    /// - Parameter image: UIImage
    /// - Returns: OCRResult
    func recognizeText(from image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        // Vision request oluştur
        let request = VNRecognizeTextRequest()
        
        // Ayarlar
        request.recognitionLevel = .accurate // Fast veya Accurate
        request.recognitionLanguages = ["tr-TR", "en-US"] // Türkçe ve İngilizce
        request.usesLanguageCorrection = true
        
        // Request handler
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // İşlemi çalıştır
        try handler.perform([request])
        
        // Sonuçları al
        guard let observations = request.results, !observations.isEmpty else {
            throw OCRError.noTextFound
        }
        
        // Metinleri birleştir
        var fullText = ""
        var confidences: [Float] = []
        var boundingBoxes: [CGRect] = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else {
                continue
            }
            
            fullText += topCandidate.string + "\n"
            confidences.append(topCandidate.confidence)
            boundingBoxes.append(observation.boundingBox)
        }
        
        // Ortalama güven skoru
        let avgConfidence = confidences.isEmpty ? 0.0 : confidences.reduce(0, +) / Float(confidences.count)
        
        return OCRResult(
            text: fullText,
            confidence: avgConfidence,
            boundingBoxes: boundingBoxes
        )
    }
    
    /// Hızlı OCR - düşük hassasiyet ama hızlı
    func quickRecognize(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.recognitionLanguages = ["tr-TR", "en-US"]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        
        guard let observations = request.results else {
            throw OCRError.noTextFound
        }
        
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
    
    /// Belirli bir bölgedeki metni çıkar
    func recognizeText(from image: UIImage, in region: CGRect) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        // Bölgeyi crop et
        guard let croppedImage = cgImage.cropping(to: region) else {
            throw OCRError.cropFailed
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["tr-TR", "en-US"]
        
        let handler = VNImageRequestHandler(cgImage: croppedImage, options: [:])
        try handler.perform([request])
        
        guard let observations = request.results else {
            throw OCRError.noTextFound
        }
        
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}

// MARK: - Error Types

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case cropFailed
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Geçersiz resim formatı"
        case .noTextFound:
            return "Resimde metin bulunamadı"
        case .cropFailed:
            return "Resim kırpılamadı"
        case .processingFailed(let message):
            return "İşlem hatası: \(message)"
        }
    }
}

// MARK: - Image Processing Helpers

extension OCRService {
    /// Resmi OCR için optimize et
    func preprocessImage(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let context = CIContext()
        
        // Kontrast artır
        let contrastFilter = CIFilter(name: "CIColorControls")
        contrastFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        contrastFilter?.setValue(1.2, forKey: kCIInputContrastKey) // Kontrast artır
        
        guard let outputImage = contrastFilter?.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// Resmi siyah-beyaz yap (OCR için daha iyi)
    func convertToGrayscale(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let context = CIContext()
        let filter = CIFilter(name: "CIPhotoEffectNoir")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let outputImage = filter?.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}
