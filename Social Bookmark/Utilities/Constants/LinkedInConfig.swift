import Foundation

struct LinkedInConfig {
    let clientID: String
    let clientSecret: String
    let redirectURI: String
    let scopes: [String]

    static let shared = LinkedInConfig()

    init(
        clientID: String? = nil,
        clientSecret: String? = nil,
        redirectURI: String? = nil,
        scopes: [String]? = nil
    ) {
        self.clientID = clientID ?? LinkedInConfig.value(for: "LINKEDIN_CLIENT_ID")
        self.clientSecret = clientSecret ?? LinkedInConfig.value(for: "LINKEDIN_CLIENT_SECRET")
        self.redirectURI = redirectURI ?? LinkedInConfig.value(for: "LINKEDIN_REDIRECT_URI")
        let defaultScopes = LinkedInConfig.value(
            for: "LINKEDIN_SCOPES",
            fallback: "r_liteprofile r_organization_social w_member_social"
        )
        self.scopes = scopes ?? defaultScopes
            .split(separator: " ")
            .map { String($0) }
    }

    private static func value(for key: String, fallback: String = "") -> String {
        if let infoValue = Bundle.main.object(forInfoDictionaryKey: key) as? String, !infoValue.isEmpty {
            return infoValue
        }

        if let envValue = ProcessInfo.processInfo.environment[key], !envValue.isEmpty {
            return envValue
        }

        return fallback
    }
}
