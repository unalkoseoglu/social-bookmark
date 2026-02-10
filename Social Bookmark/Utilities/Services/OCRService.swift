import Vision
import UIKit
import ImageIO

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
            
            // 1. Kişi ismi algıla (Büyük Harf + Büyük Harf formatı) - Genelde tweet sahipleri
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
                
                // En az 10 karakter (biraz daha toleranslı)
                guard trimmed.count >= 10 else { return false }
                // En fazla 120 karakter
                guard trimmed.count <= 120 else { return false }
                // En az 2 kelime
                guard trimmed.split(separator: " ").count >= 2 else { return false }
                
                return true
            }
            
            // İlk anlamlı satırı döndür
            if let firstMeaningful = meaningfulLines.first {
                return truncateTitle(firstMeaningful)
            }
            
            // 3. Fallback: İlk satır
            if let firstLine = lines.first {
                let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    return truncateTitle(trimmed)
                }
            }
            
            return nil
        }
        
        /// Kişi ismi algılama - "Ad Soyad" formatı
        private func detectPersonName(in lines: [String]) -> String? {
            for line in lines.prefix(5) { // İlk 5 satıra bak
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                // İki veya üç kelime kontrolü
                let words = trimmed.split(separator: " ")
                guard words.count >= 2 && words.count <= 4 else { continue }
                
                // Her kelime büyük harfle başlamalı
                let allCapitalized = words.allSatisfy { word in
                    guard let firstChar = word.first else { return false }
                    return firstChar.isUppercase
                }
                
                guard allCapitalized else { continue }
                
                // İsimler genelde sayı içermez
                guard !trimmed.contains(where: { $0.isNumber }) else { continue }
                
                // Sadece harf ve boşluk olmalı
                let allowedCharset = CharacterSet.letters.union(.whitespaces)
                guard trimmed.rangeOfCharacter(from: allowedCharset.inverted) == nil else { continue }
                
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
                if testString.count > 77 {
                    break
                }
                result = testString
            }
            
            return result.isEmpty ? String(trimmed.prefix(77)) + "..." : result + "..."
        }
        
        /// Akıllı temizleme - gereksiz UI elementlerini filtrele
        private func smartClean(_ text: String) -> String {
            let lines = text.components(separatedBy: "\n")
            var cleanedLines: [String] = []
            
            // Yaygın screenshot UI elementleri (Regex ile daha güvenli)
            let uiPatterns = [
                "^\\d{1,2}:\\d{2}$", // Saat
                "^\\d{1,3}%?'?$",    // Batarya
                "^[\\.\\-…•\\*]+$",   // Sadece semboller
                "^[0-9]+$",          // Sadece sayılar (liste no değilse)
                "^LTE|4G|5G|WiFi$",  // Bağlantı
                "^Done|Cancel|Edit|Next|Back|Save|Open|Share|Copy$", // UI butonları
                "^Tüm Notlar|Notlar|Tags|Etiketler|Kategoriler$"       // App UI
            ]
            
            let combinedPattern = uiPatterns.joined(separator: "|")
            let regex = try? NSRegularExpression(pattern: combinedPattern, options: .caseInsensitive)
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                
                // Regex check
                let range = NSRange(location: 0, length: trimmed.utf16.count)
                if let match = regex?.firstMatch(in: trimmed, options: [], range: range), match.range == range {
                    continue
                }
                
                // Sosyal medya platform isimleri
                let skipList = ["twitter.com", "x.com", "instagram.com", "linkedin.com", "reddit.com", "medium.com"]
                if skipList.contains(where: { trimmed.lowercased() == $0 }) {
                    continue
                }
                
                // Tek karakterli satırlar harf değilse atla
                if trimmed.count == 1 && trimmed.rangeOfCharacter(from: .letters) == nil {
                    continue
                }
                
                // Twitter handle tek başına ise (ve çok kısaysa) atla
                if trimmed.hasPrefix("@") && !trimmed.contains(" ") && trimmed.count < 15 {
                    continue
                }
                
                // Emoji sadece satırlar
                if trimmed.unicodeScalars.allSatisfy({ $0.properties.isEmoji }) {
                    continue
                }
                
                cleanedLines.append(trimmed)
            }
            
            return mergeLines(cleanedLines)
        }
        
        /// Satır sonlarını akıllıca birleştir - doğal paragraf akışı sağla
        private func mergeLines(_ lines: [String]) -> String {
            guard !lines.isEmpty else { return "" }
            
            var merged: [String] = []
            var currentParagraph = ""
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                if currentParagraph.isEmpty {
                    currentParagraph = trimmed
                    continue
                }
                
                // Paragraf bitiş işaretleri
                let sentenceEnders: Set<Character> = [".", "!", "?", ":"]
                let lastChar = currentParagraph.last ?? " "
                
                // Yeni paragraf belirtileri:
                // 1. Önceki satır . ! ? : ile biterse
                // 2. Bu satır liste başıysa (1. - • *)
                // 3. Bu satır büyük harfle başlıyorsa VE önceki satır yeterince uzunsa
                
                let isNewList = trimmed.range(of: "^(\\d+[\\.)\\-]|[-•\\*])", options: .regularExpression) != nil
                let startsWithUpper = trimmed.first?.isUppercase ?? false
                let prevIsLong = currentParagraph.count > 50
                
                if sentenceEnders.contains(lastChar) || isNewList || (startsWithUpper && prevIsLong) {
                    merged.append(currentParagraph)
                    currentParagraph = trimmed
                } else {
                    currentParagraph += " " + trimmed
                }
            }
            
            if !currentParagraph.isEmpty {
                merged.append(currentParagraph)
            }
            
            return merged.joined(separator: "\n\n")
        }
    }
    
    // MARK: - Public Methods
    
    /// Resimden metin çıkar (Optimize edilmiş)
    func recognizeText(from image: UIImage) async throws -> OCRResult {
        // 1. Ön İşleme (Preprocessing)
        // Background queue'da yapalım ki UI bloklanmasın (metod asenkron olsa da CPU yoğun işler)
        return try await Task.detached(priority: .userInitiated) {
            let optimizedImage = self.preprocessForOCR(image)
            
            guard let cgImage = optimizedImage.cgImage else {
                throw OCRError.invalidImage
            }
            
            // Orientation düzeltme
            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            
            return try await withCheckedThrowingContinuation { continuation in
                let request = VNRecognizeTextRequest { request, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(throwing: OCRError.noTextFound)
                        return
                    }
                    
                    if observations.isEmpty {
                        continuation.resume(throwing: OCRError.noTextFound)
                        return
                    }
                    
                    var fullText = ""
                    var confidences: [Float] = []
                    var boundingBoxes: [CGRect] = []
                    
                    // Observations genelde üstten aşağıdır
                    for observation in observations {
                        guard let topCandidate = observation.topCandidates(1).first else { continue }
                        fullText += topCandidate.string + "\n"
                        confidences.append(topCandidate.confidence)
                        boundingBoxes.append(observation.boundingBox)
                    }
                    
                    let avgConfidence = confidences.isEmpty ? 0.0 : confidences.reduce(0, +) / Float(confidences.count)
                    
                    continuation.resume(returning: OCRResult(
                        text: fullText,
                        confidence: avgConfidence,
                        boundingBoxes: boundingBoxes
                    ))
                }
                
                // Hassasiyet Ayarları
                request.recognitionLevel = .accurate
                
                // Dil Desteği - Cihazın desteklediği dilleri de alabiliriz ama şimdilik TR/EN garanti
                request.recognitionLanguages = ["tr-TR", "en-US"]
                request.usesLanguageCorrection = true
                
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }.value
    }
    
    /// Hızlı OCR - düşük hassasiyet ama hızlı
    func quickRecognize(from image: UIImage) async throws -> String {
        let result = try await recognizeText(from: image)
        return result.cleanText
    }
    
    /// Belirli bir bölgedeki metni çıkar
    func recognizeText(from image: UIImage, in region: CGRect) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        // CGImage cropping coordinates are normalized if using Vision, but here we expect absolute pixels
        guard let croppedImage = cgImage.cropping(to: region) else {
            throw OCRError.cropFailed
        }
        
        let uiImage = UIImage(cgImage: croppedImage)
        let result = try await recognizeText(from: uiImage)
        return result.text
    }
    
    // MARK: - Preprocessing Logic
    
    /// OCR için resimi optimize et: Resize -> Grayscale -> Contrast
    private func preprocessForOCR(_ image: UIImage) -> UIImage {
        // 1. Resize (Çok büyük resimler Vision'ı yavaşlatır, çok küçükler doğruluk düşürür)
        // İdeal OCR boyutu: Kısa kenar ~1200-1500px
        let targetSize = calculateOCRSize(for: image.size)
        let resized = resizeImage(image, to: targetSize) ?? image
        
        // 2. Grayscale & Contrast
        guard let ciImage = CIImage(image: resized) else { return resized }
        
        let context = CIContext(options: [.useSoftwareRenderer: false])
        
        // Noir filter (Grayscale)
        let noir = CIFilter(name: "CIPhotoEffectNoir")
        noir?.setValue(ciImage, forKey: kCIInputImageKey)
        
        // Contrast enhancement
        let contrast = CIFilter(name: "CIColorControls")
        contrast?.setValue(noir?.outputImage ?? ciImage, forKey: kCIInputImageKey)
        contrast?.setValue(1.4, forKey: kCIInputContrastKey) // Kontrastı belirgin artır
        
        if let output = contrast?.outputImage,
           let cgImage = context.createCGImage(output, from: output.extent) {
            return UIImage(cgImage: cgImage)
        }
        
        return resized
    }
    
    private func calculateOCRSize(for originalSize: CGSize) -> CGSize {
        let maxDimension: CGFloat = 2000.0 // OCR için makul maksimum genişlik/yükseklik
        
        if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
            return originalSize
        }
        
        let aspectRatio = originalSize.width / originalSize.height
        
        if originalSize.width > originalSize.height {
            return CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            return CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // Scale 1.0 önemli, yoksa retina ekranlarda çok büyük olur
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Orientation Helper

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
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
            return String(localized: "ocr.error.invalid_image")
        case .noTextFound:
            return String(localized: "ocr.error.no_text")
        case .cropFailed:
            return String(localized: "ocr.error.crop_failed")
        case .processingFailed(let message):
            return "\(String(localized: "ocr.error.processing")): \(message)"
        }
    }
}
