import Foundation
import Combine

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case unauthorized
    case forbidden
    case unexpectedStatusCode(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Geçersiz URL"
        case .noData: return "Veri alınamadı"
        case .decodingError: return "Veri işlenemedi"
        case .serverError(let msg): return msg
        case .unauthorized: return "Oturum geçersiz"
        case .forbidden: return "Yetkisiz erişim"
        case .unexpectedStatusCode(let code): return "Sunucu hatası (\(code))"
        }
    }
}

final class NetworkManager {
    static let shared = NetworkManager()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: configuration)
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .useDefaultKeys
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async throws -> T {
        guard let url = URL(string: APIConstants.baseURL.absoluteString + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        
        // Default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Auth token
        if let token = UserDefaults.standard.string(forKey: APIConstants.Keys.token) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Custom headers
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        print("🌐 [Network] \(method) \(url.absoluteString)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverError("Geçersiz yanıt")
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            if T.self is EmptyResponse.Type {
                return EmptyResponse() as! T
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                print("❌ [Network] Decoding Error: \(error)")
                throw NetworkError.decodingError
            }
        case 401:
            throw NetworkError.unauthorized
        case 403:
            throw NetworkError.forbidden
        default:
            if let serverError = try? JSONDecoder().decode(ServerErrorResponse.self, from: data) {
                throw NetworkError.serverError(serverError.message)
            }
            throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
        }
    }
    
    func upload<T: Decodable>(
        endpoint: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fieldName: String = "file"
    ) async throws -> T {
        guard let url = URL(string: APIConstants.baseURL.absoluteString + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Auth token
        if let token = UserDefaults.standard.string(forKey: APIConstants.Keys.token) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = NSMutableData()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body as Data
        
        print("🌐 [Network] UPLOAD \(url.absoluteString) (\(fileData.count / 1024) KB)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverError("Geçersiz yanıt")
        }
        
        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
            return try decoder.decode(T.self, from: data)
        } else {
            if let serverError = try? JSONDecoder().decode(ServerErrorResponse.self, from: data) {
                throw NetworkError.serverError(serverError.message)
            }
            throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
        }
    }
}

struct ServerErrorResponse: Decodable {
    let message: String
}
