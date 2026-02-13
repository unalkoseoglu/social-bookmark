import Foundation
import Combine
import SwiftUI
import OSLog

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
        case .invalidURL: return String(localized: "network.error.invalid_url")
        case .noData: return String(localized: "network.error.no_data")
        case .decodingError: return String(localized: "network.error.decoding_error")
        case .serverError(let msg): return msg
        case .unauthorized: return String(localized: "network.error.unauthorized")
        case .forbidden: return String(localized: "network.error.forbidden")
        case .unexpectedStatusCode(let code): return String(localized: "network.error.unexpected_status_code \(Int64(code))")
        }
    }
}

final class NetworkManager {
    static let shared = NetworkManager()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    
    private var defaults: UserDefaults {
        UserDefaults(suiteName: APIConstants.appGroupId) ?? .standard
    }
    
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
        queryParameters: [String: String]? = nil,
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async throws -> T {
        let urlString = APIConstants.baseURL.absoluteString + endpoint
        
        guard var components = URLComponents(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        if let queryParameters = queryParameters {
            components.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        
        // Default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Auth token
        if let token = defaults.string(forKey: APIConstants.Keys.token) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Custom headers
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        Logger.network.debug("🌐 [Network] \(method) \(url.absoluteString)")
        
        let startTime = Date()
        
        do {
            let (data, response) = try await session.data(for: request)
            
            NetworkLogger.shared.log(
                url: url.absoluteString,
                method: method,
                requestHeaders: request.allHTTPHeaderFields,
                requestBody: request.httpBody,
                response: response,
                responseBody: data,
                error: nil,
                duration: Date().timeIntervalSince(startTime)
            )
            
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
                    Logger.network.error("❌ [Network] Decoding Error: \(error)")
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
        } catch {
            NetworkLogger.shared.log(
                url: url.absoluteString,
                method: method,
                requestHeaders: request.allHTTPHeaderFields,
                requestBody: request.httpBody,
                response: nil,
                responseBody: nil,
                error: error,
                duration: Date().timeIntervalSince(startTime)
            )
            throw error
        }
    }
    
    struct FileUpload {
        let data: Data
        let fileName: String
        let mimeType: String
        let fieldName: String
    }

    func upload<T: Decodable>(
        endpoint: String,
        files: [FileUpload] = [],
        additionalFields: [String: String] = [:]
    ) async throws -> T {
        guard let url = URL(string: APIConstants.baseURL.absoluteString + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = defaults.string(forKey: APIConstants.Keys.token) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = NSMutableData()
        
        for (key, value) in additionalFields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        for file in files {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body as Data
        
        let totalSize = files.reduce(0) { $0 + $1.data.count }
        let startTime = Date()
        
        Logger.network.info("🌐 [Network] MULTIPART UPLOAD \(url.absoluteString) (\(totalSize / 1024) KB, \(files.count) files)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            NetworkLogger.shared.log(
                url: url.absoluteString,
                method: "POST",
                requestHeaders: request.allHTTPHeaderFields,
                requestBody: nil, // Don't log full multipart body to save memory
                response: response,
                responseBody: data,
                error: nil,
                duration: Date().timeIntervalSince(startTime)
            )
            
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
        } catch {
            NetworkLogger.shared.log(
                url: url.absoluteString,
                method: "POST",
                requestHeaders: request.allHTTPHeaderFields,
                requestBody: nil,
                response: nil,
                responseBody: nil,
                error: error,
                duration: Date().timeIntervalSince(startTime)
            )
            throw error
        }
    }
}

struct ServerErrorResponse: Decodable {
    let message: String
}

// MARK: - Network Logger

/// Represents a single network request log
struct NetworkLog: Identifiable, Sendable {
    let id: UUID
    let url: String
    let method: String
    let requestHeaders: [String: String]?
    let requestBody: String?
    let statusCode: Int?
    let responseHeaders: [String: String]?
    let responseBody: String?
    let error: String?
    let duration: TimeInterval
    let date: Date
    
    var statusColor: Color {
        if let code = statusCode {
            switch code {
            case 200...299: return .green
            case 300...399: return .yellow
            case 400...599: return .red
            default: return .gray
            }
        }
        return error != nil ? .red : .gray
    }
}

/// Singleton logger to store network requests
actor NetworkLogger {
    static let shared = NetworkLogger()
    
    private(set) var logs: [NetworkLog] = []
    
    private init() {}
    
    nonisolated func log(
        url: String,
        method: String,
        requestHeaders: [String: String]?,
        requestBody: Data?,
        response: URLResponse?,
        responseBody: Data?,
        error: Error?,
        duration: TimeInterval
    ) {
        Task {
            await addLog(
                url: url,
                method: method,
                requestHeaders: requestHeaders,
                requestBody: requestBody,
                response: response,
                responseBody: responseBody,
                error: error,
                duration: duration
            )
        }
    }
    
    private func addLog(
        url: String,
        method: String,
        requestHeaders: [String: String]?,
        requestBody: Data?,
        response: URLResponse?,
        responseBody: Data?,
        error: Error?,
        duration: TimeInterval
    ) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        let responseHeaders = (response as? HTTPURLResponse)?.allHeaderFields as? [String: String]
        
        let reqBodyStr = requestBody.flatMap { String(data: $0, encoding: .utf8) } ?? (requestBody != nil ? "\(requestBody!.count) bytes" : nil)
        
        // Try pretty print JSON for response
        var respBodyStr: String?
        if let data = responseBody {
            if let json = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
                respBodyStr = String(data: prettyData, encoding: .utf8)
            } else {
                respBodyStr = String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
            }
        }
        
        let newLog = NetworkLog(
            id: UUID(),
            url: url,
            method: method,
            requestHeaders: requestHeaders,
            requestBody: reqBodyStr,
            statusCode: statusCode,
            responseHeaders: responseHeaders,
            responseBody: respBodyStr,
            error: error?.localizedDescription,
            duration: duration,
            date: Date()
        )
        
        logs.insert(newLog, at: 0)
        
        // Limit logs to keep memory sane
        if logs.count > 50 {
            logs.removeLast()
        }
    }
    
    func clear() {
        logs.removeAll()
    }
    
    func getLogs() -> [NetworkLog] {
        return logs
    }
}
