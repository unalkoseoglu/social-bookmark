import Foundation

struct AuthUser: Codable, Identifiable {
    let id: UUID
    let email: String?
    let isAnonymous: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case isAnonymous = "is_anonymous"
    }
}

struct AuthResponse: Codable {
    let user: AuthUser
    let accessToken: String
    
    enum CodingKeys: String, CodingKey {
        case user
        case accessToken = "access_token"
    }
}
