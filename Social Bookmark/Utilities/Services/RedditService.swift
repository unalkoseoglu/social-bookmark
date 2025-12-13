import Foundation

struct RedditPost: Equatable {
    let title: String
    let author: String
    let subreddit: String
    let selfText: String
    let imageURL: URL?
    let score: Int
    let commentCount: Int
    let originalURL: URL

    var authorDisplay: String { "u/\(author)" }
    var subtitle: String { "\(authorDisplay) • r/\(subreddit)" }

    var summary: String {
        let trimmed = selfText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? subtitle : trimmed
    }
}

enum RedditError: LocalizedError {
    case invalidURL
    case notFound
    case decodingFailed
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Geçersiz Reddit URL'si"
        case .notFound:
            return "Reddit gönderisi bulunamadı"
        case .decodingFailed:
            return "Reddit yanıtı çözümlenemedi"
        case .networkError:
            return "Reddit isteği başarısız oldu"
        }
    }
}

protocol RedditPostProviding {
    func fetchPost(from urlString: String) async throws -> RedditPost
    func isRedditURL(_ urlString: String) -> Bool
}

final class RedditService: RedditPostProviding {
    static let shared = RedditService()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchPost(from urlString: String) async throws -> RedditPost {
        guard let url = URL(string: urlString) else {
            throw RedditError.invalidURL
        }

        let resolvedURL = try await resolveCanonicalURL(from: url)

        guard let apiURL = redditJSONURL(from: resolvedURL) else {
            throw RedditError.invalidURL
        }

        var request = URLRequest(url: apiURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 12

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RedditError.networkError
            }

            guard httpResponse.statusCode == 200 else {
                throw RedditError.notFound
            }

            let post = try decodePost(from: data, originalURL: url)
            return post
        } catch is DecodingError {
            throw RedditError.decodingFailed
        } catch {
            if error is RedditError { throw error }
            throw RedditError.networkError
        }
    }

    func isRedditURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("reddit.com/") || lowercased.contains("redd.it/")
    }

    // MARK: - Private Helpers

    private func resolveCanonicalURL(from url: URL) async throws -> URL {
        let requiresResolution = (url.host?.contains("redd.it") ?? false) || url.path.contains("/s/")
        guard requiresResolution else { return url }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8

        do {
            let (_, response) = try await session.data(for: request)
            if let redirectedURL = (response as? HTTPURLResponse)?.url ?? response.url {
                return redirectedURL
            }
        } catch {
            return url
        }

        return url
    }

    private func redditJSONURL(from url: URL) -> URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if components?.scheme == nil {
            components?.scheme = "https"
        }

        if let host = components?.host, host.contains("redd.it") {
            components?.host = "www.reddit.com"
        }

        let trimmedPath = (components?.path ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedPath = "/\(trimmedPath)"
        components?.path = normalizedPath.hasSuffix(".json") ? normalizedPath : normalizedPath + ".json"

        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "raw_json", value: "1"))
        components?.queryItems = queryItems
        components?.fragment = nil

        return components?.url
    }

    private func decodePost(from data: Data, originalURL: URL) throws -> RedditPost {
        let decoder = JSONDecoder()

        let postData: RedditPostData

        if let listings = try? decoder.decode([RedditListing].self, from: data),
           let first = listings.first?.data.children.first?.data {
            postData = first
        } else if let listing = try? decoder.decode(RedditListing.self, from: data),
                  let first = listing.data.children.first?.data {
            postData = first
        } else if let listings = try? decoder.decode([RedditListing].self, from: data),
                  !listings.isEmpty {
            throw RedditError.notFound
        } else if let listing = try? decoder.decode(RedditListing.self, from: data),
                  !listing.data.children.isEmpty {
            throw RedditError.notFound
        } else {
            throw RedditError.decodingFailed
        }

        let imageURL = extractImageURL(from: postData)

        return RedditPost(
            title: postData.title,
            author: postData.author,
            subreddit: postData.subreddit,
            selfText: postData.selftext ?? "",
            imageURL: imageURL,
            score: postData.ups ?? 0,
            commentCount: postData.num_comments ?? 0,
            originalURL: originalURL
        )
    }

    private func extractImageURL(from data: RedditPostData) -> URL? {
        if let previewURL = data.preview?.images?.first?.source.url?.replacingOccurrences(of: "&amp;", with: "&"),
           let url = URL(string: previewURL) {
            return url
        }

        if let overridden = data.url_overridden_by_dest,
           isImageURL(overridden) {
            return URL(string: overridden)
        }

        if let thumbnail = data.thumbnail,
           thumbnail.hasPrefix("http"),
           let url = URL(string: thumbnail) {
            return url
        }

        return nil
    }

    private func isImageURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.hasSuffix(".jpg") || lowercased.hasSuffix(".jpeg") || lowercased.hasSuffix(".png") || lowercased.hasSuffix(".gif")
    }
}

// MARK: - API Response Models

private struct RedditListing: Codable {
    let data: RedditListingData
}

private struct RedditListingData: Codable {
    let children: [RedditPostContainer]
}

private struct RedditPostContainer: Codable {
    let data: RedditPostData
}

private struct RedditPostData: Codable {
    let title: String
    let author: String
    let subreddit: String
    let selftext: String?
    let ups: Int?
    let num_comments: Int?
    let url_overridden_by_dest: String?
    let thumbnail: String?
    let preview: RedditPreview?
}

private struct RedditPreview: Codable {
    let images: [RedditPreviewImage]?
}

private struct RedditPreviewImage: Codable {
    let source: RedditPreviewSource
}

private struct RedditPreviewSource: Codable {
    let url: String
}
