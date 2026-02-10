import Foundation
import SwiftUI

struct ExtractedContent {
    let title: String
    let note: String
    let imageURLs: [URL]
    let author: String?
    let source: BookmarkSource
    
    // Platform-specific models for preview
    var tweet: TwitterService.Tweet?
    var redditPost: RedditPost?
    var linkedinPost: LinkedInPost?
    var mediumPost: MediumPost?
    var genericMetadata: URLMetadataService.URLMetadata?

    init(
        title: String,
        note: String,
        imageURLs: [URL],
        author: String?,
        source: BookmarkSource,
        tweet: TwitterService.Tweet? = nil,
        redditPost: RedditPost? = nil,
        linkedinPost: LinkedInPost? = nil,
        mediumPost: MediumPost? = nil,
        genericMetadata: URLMetadataService.URLMetadata? = nil
    ) {
        self.title = title
        self.note = note
        self.imageURLs = imageURLs
        self.author = author
        self.source = source
        self.tweet = tweet
        self.redditPost = redditPost
        self.linkedinPost = linkedinPost
        self.mediumPost = mediumPost
        self.genericMetadata = genericMetadata
    }
}

enum ExtractionError: LocalizedError {
    case twitter(TwitterError)
    case reddit(RedditService.RedditError)
    case linkedin(LinkedInService.LinkedInError)
    case medium(MediumService.MediumError)
    case network(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .twitter(let error): return error.localizedDescription
        case .reddit(let error): return error.localizedDescription
        case .linkedin(let error): return error.localizedDescription
        case .medium(let error): return error.localizedDescription
        case .network(let message): return message
        case .unknown(let message): return message
        }
    }
}

final class BookmarkExtractionService {
    static let shared = BookmarkExtractionService()
    
    private init() {}
    
    func extract(from urlString: String) async throws -> ExtractedContent {
        if TwitterService.shared.isTwitterURL(urlString) {
            return try await extractTwitter(from: urlString)
        } else if RedditService.shared.isRedditURL(urlString) {
            return try await extractReddit(from: urlString)
        } else if LinkedInService.shared.isLinkedInURL(urlString) {
            return try await extractLinkedIn(from: urlString)
        } else if MediumService.shared.isMediumURL(urlString) {
            return try await extractMedium(from: urlString)
        } else {
            return try await extractGeneric(from: urlString)
        }
    }
    
    private func extractTwitter(from urlString: String) async throws -> ExtractedContent {
        do {
            let tweet = try await TwitterService.shared.fetchTweet(from: urlString)
            let title = smartTitle(from: tweet.text)
            let author = "@\(tweet.authorUsername)"
            return ExtractedContent(
                title: title,
                note: tweet.text,
                imageURLs: tweet.mediaURLs,
                author: author,
                source: .twitter,
                tweet: tweet
            )
        } catch let error as TwitterError {
            throw ExtractionError.twitter(error)
        } catch {
            throw ExtractionError.unknown(error.localizedDescription)
        }
    }
    
    private func extractReddit(from urlString: String) async throws -> ExtractedContent {
        do {
            let post = try await RedditService.shared.fetchPost(from: urlString)
            return ExtractedContent(
                title: post.title,
                note: post.summary,
                imageURLs: [post.imageURL].compactMap { $0 },
                author: nil,
                source: .reddit,
                redditPost: post
            )
        } catch let error as RedditService.RedditError {
            throw ExtractionError.reddit(error)
        } catch {
            throw ExtractionError.unknown(error.localizedDescription)
        }
    }
    
    private func extractLinkedIn(from urlString: String) async throws -> ExtractedContent {
        do {
            let post = try await LinkedInService.shared.fetchPost(from: urlString)
            return ExtractedContent(
                title: post.title,
                note: post.content,
                imageURLs: [post.imageURL].compactMap { $0 },
                author: nil,
                source: .linkedin,
                linkedinPost: post
            )
        } catch let error as LinkedInService.LinkedInError {
            throw ExtractionError.linkedin(error)
        } catch {
            throw ExtractionError.unknown(error.localizedDescription)
        }
    }
    
    private func extractMedium(from urlString: String) async throws -> ExtractedContent {
        do {
            let post = try await MediumService.shared.fetchPost(from: urlString)
            var combinedNote = post.subtitle
            if post.hasFullContent {
                if !combinedNote.isEmpty { combinedNote += "\n\n" }
                combinedNote += post.fullContent
            }
            return ExtractedContent(
                title: post.title,
                note: combinedNote,
                imageURLs: [post.imageURL].compactMap { $0 },
                author: nil,
                source: .medium,
                mediumPost: post
            )
        } catch let error as MediumService.MediumError {
            throw ExtractionError.medium(error)
        } catch {
            throw ExtractionError.unknown(error.localizedDescription)
        }
    }
    
    private func extractGeneric(from urlString: String) async throws -> ExtractedContent {
        guard let metadata = try? await URLMetadataService.shared.fetchMetadata(from: urlString) else {
            throw ExtractionError.network("Could not fetch metadata")
        }
        return ExtractedContent(
            title: metadata.title ?? "",
            note: metadata.description ?? "",
            imageURLs: [metadata.imageURL].compactMap { $0 },
            author: nil,
            source: .other,
            genericMetadata: metadata
        )
    }
    
    // MARK: - Helpers
    
    private func smartTitle(from text: String, maxLength: Int = 100) -> String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanText.isEmpty { return "" }
        
        let delimiters: Set<Character> = [".", "!", "?", "\n"]
        var firstDelimiterIndex: String.Index? = nil
        
        for index in cleanText.indices {
            if delimiters.contains(cleanText[index]) {
                if cleanText[index] == "." {
                    let nextIndex = cleanText.index(after: index)
                    if nextIndex < cleanText.endIndex, cleanText[nextIndex].isNumber {
                        continue
                    }
                }
                firstDelimiterIndex = index
                break
            }
        }
        
        if let delimiterIndex = firstDelimiterIndex {
            let sentence = cleanText[...delimiterIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.count <= maxLength + 20 {
                return String(sentence)
            }
        }
        
        if cleanText.count <= maxLength {
            return cleanText
        }
        
        let truncated = cleanText.prefix(maxLength)
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "..."
        }
        
        return String(truncated) + "..."
    }
}
