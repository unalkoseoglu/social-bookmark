import Foundation

enum APIConstants {
    #if DEBUG
    static let baseURL = URL(string: "https://linkbookmark.tarikmaden.com/api/v1")!
    #else
    static let baseURL = URL(string: "https://linkbookmark.tarikmaden.com/api/v1")!
    #endif
    
    static let appGroupId = "group.com.unal.socialbookmark"
    
    enum Endpoints {
        static let login = "/auth/login"
        static let register = "/auth/register"
        static let logout = "/auth/logout"
        static let profile = "/profile"
        static let bookmarks = "/bookmarks"
        static let bookmarksUpsert = "/bookmarks/upsert"
        static let categories = "/categories"
        static let categoriesUpsert = "/categories/upsert"
        static let upload = "/media/upload"
        static let syncDelta = "/sync/delta"
    }
    
    enum Keys {
        static let token = "api_auth_token"
        static let lastSync = "api_last_sync_timestamp"
    }
}
