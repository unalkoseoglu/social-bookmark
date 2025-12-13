import SwiftUI

struct RedditPreviewView: View {
    let post: RedditPost

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("r/\(post.subreddit)", systemImage: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(.orange)
                    .font(.headline)
                Spacer()
                Text(post.authorDisplay)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(post.title)
                .font(.title3)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)

            if !post.summary.isEmpty {
                Text(post.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
            }

            if let imageURL = post.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 140)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            HStack(spacing: 16) {
                Label("\(post.score)", systemImage: "arrow.up")
                    .foregroundStyle(.orange)
                Label("\(post.commentCount)", systemImage: "text.bubble")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RedditPreviewView(
        post: RedditPost(
            title: "I built a SwiftUI bookmark manager!",
            author: "swiftdev",
            subreddit: "iOSProgramming",
            selfText: "Here's how I structured the data models and handled asynchronous fetching.",
            imageURL: URL(string: "https://i.redd.it/example.png"),
            score: 4200,
            commentCount: 182,
            originalURL: URL(string: "https://reddit.com/r/iOSProgramming/")!
        )
    )
    .padding()
}
