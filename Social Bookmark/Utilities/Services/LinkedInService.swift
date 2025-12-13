import Foundation
import Security

// MARK: - Models

struct LinkedInAccessToken: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date().addingTimeInterval(-60)
    }
}

struct LinkedInContent: Codable, Equatable {
    let title: String
    let summary: String
    let imageURL: URL?
    let author: String
}

enum LinkedInError: Error, LocalizedError {
    case missingCredentials
    case authorizationRequired
    case invalidURL
    case networkError
    case failedToDecode

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "LinkedIn credentials are missing."
        case .authorizationRequired:
            return "Authorization is required to access LinkedIn content."
        case .invalidURL:
            return "Provided LinkedIn URL is invalid."
        case .networkError:
            return "A network error occurred while contacting LinkedIn."
        case .failedToDecode:
            return "LinkedIn response could not be decoded."
        }
    }
}

// MARK: - Protocols

protocol LinkedInAuthProviding {
    func cachedToken() -> LinkedInAccessToken?
    func store(token: LinkedInAccessToken) throws
    func ensureValidToken() async throws -> LinkedInAccessToken
}

protocol LinkedInContentProviding {
    func fetchContent(from url: URL, token: LinkedInAccessToken) async throws -> LinkedInContent
}

// MARK: - Keychain Storage

class LinkedInTokenStore {
    private let service = "com.socialbookmark.linkedin"
    private let account = "linkedin_access_token"

    func save(_ token: LinkedInAccessToken) throws {
        let data = try JSONEncoder().encode(token)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw LinkedInError.networkError }
    }

    func load() -> LinkedInAccessToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }

        return try? JSONDecoder().decode(LinkedInAccessToken.self, from: data)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Auth Client

final class LinkedInAuthClient: LinkedInAuthProviding {
    private let config: LinkedInConfig
    private let session: URLSession
    private let tokenStore: LinkedInTokenStore

    init(
        config: LinkedInConfig = .shared,
        session: URLSession = .shared,
        tokenStore: LinkedInTokenStore = LinkedInTokenStore()
    ) {
        self.config = config
        self.session = session
        self.tokenStore = tokenStore
    }

    func cachedToken() -> LinkedInAccessToken? {
        tokenStore.load()
    }

    func store(token: LinkedInAccessToken) throws {
        try tokenStore.save(token)
    }

    func ensureValidToken() async throws -> LinkedInAccessToken {
        guard let token = tokenStore.load() else {
            throw LinkedInError.authorizationRequired
        }

        guard token.isExpired, let refreshToken = token.refreshToken else {
            return token
        }

        let refreshed = try await refreshAccessToken(refreshToken: refreshToken)
        try tokenStore.save(refreshed)
        return refreshed
    }

    func exchangeAuthorizationCode(_ code: String) async throws -> LinkedInAccessToken {
        guard !config.clientID.isEmpty, !config.clientSecret.isEmpty else {
            throw LinkedInError.missingCredentials
        }

        guard let url = URL(string: "https://www.linkedin.com/oauth/v2/accessToken") else {
            throw LinkedInError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "grant_type=authorization_code&code=\(code)&redirect_uri=\(config.redirectURI)&client_id=\(config.clientID)&client_secret=\(config.clientSecret)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LinkedInError.networkError
        }

        guard let token = decodeToken(from: data) else {
            throw LinkedInError.failedToDecode
        }

        try tokenStore.save(token)
        return token
    }

    func refreshAccessToken(refreshToken: String) async throws -> LinkedInAccessToken {
        guard let url = URL(string: "https://www.linkedin.com/oauth/v2/accessToken") else {
            throw LinkedInError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=\(config.clientID)&client_secret=\(config.clientSecret)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LinkedInError.networkError
        }

        guard let token = decodeToken(from: data) else {
            throw LinkedInError.failedToDecode
        }

        try tokenStore.save(token)
        return token
    }

    private func decodeToken(from data: Data) -> LinkedInAccessToken? {
        struct TokenResponse: Codable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Int?
        }

        guard let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data) else { return nil }
        let expiry = decoded.expires_in.map { Date().addingTimeInterval(TimeInterval($0)) }
        return LinkedInAccessToken(accessToken: decoded.access_token, refreshToken: decoded.refresh_token, expiresAt: expiry)
    }
}

// MARK: - Content Client

final class LinkedInContentClient: LinkedInContentProviding {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchContent(from url: URL, token: LinkedInAccessToken) async throws -> LinkedInContent {
        let encodedURL = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url.absoluteString

        guard let endpoint = URL(string: "https://api.linkedin.com/v2/ugcPosts?q=entityShare&url=\(encodedURL)") else {
            throw LinkedInError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LinkedInError.networkError
        }

        return try decodeContent(from: data)
    }

    private func decodeContent(from data: Data) throws -> LinkedInContent {
        struct Media: Codable {
            let status: String?
            let originalUrl: String?
        }

        struct ShareContent: Codable {
            let shareCommentary: LocalizedText?
            let shareMediaCategory: String?
            let media: [Media]?
        }

        struct LocalizedText: Codable {
            let text: String?
        }

        struct ContentResponse: Codable {
            let author: String?
            let lifecycleState: String?
            let specificContent: SpecificContent?
        }

        struct SpecificContent: Codable {
            let shareContent: ShareContent?
        }

        do {
            let response = try JSONDecoder().decode(ContentResponse.self, from: data)
            let title = response.specificContent?.shareContent?.shareCommentary?.text ?? "LinkedIn Post"
            let summary = response.lifecycleState ?? ""
            let mediaURLString = response.specificContent?.shareContent?.media?.first?.originalUrl
            let imageURL = mediaURLString.flatMap { URL(string: $0) }
            let author = response.author ?? "LinkedIn"

            return LinkedInContent(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                imageURL: imageURL,
                author: author
            )
        } catch {
            throw LinkedInError.failedToDecode
        }
    }
}
