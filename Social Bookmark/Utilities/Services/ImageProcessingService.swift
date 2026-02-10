import Foundation
import UIKit

final class ImageProcessingService {
    static let shared = ImageProcessingService()
    
    private init() {}
    
    private let fullImageMaxDimension: CGFloat = 1200 // AddBookmark için daha makul bir limit
    private let compressionQuality: CGFloat = 0.7
    
    /// Uzak bir URL'den resim indirir ve optimize eder
    func downloadAndProcessImage(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeRawData)
        }
        
        return try optimizeImage(image)
    }
    
    /// Resmi küçültür ve sıkıştırır
    func optimizeImage(_ image: UIImage) throws -> Data {
        var targetImage = image
        let maxDim = max(image.size.width, image.size.height)
        
        if maxDim > fullImageMaxDimension {
            let scale = fullImageMaxDimension / maxDim
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            targetImage = resizeImage(image, to: newSize) ?? image
        }
        
        guard let data = targetImage.jpegData(compressionQuality: compressionQuality) else {
            throw URLError(.unknown)
        }
        
        return data
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
