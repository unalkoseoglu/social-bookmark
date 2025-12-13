import SwiftUI

struct LinkedInPreviewView: View {
    let content: LinkedInContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("LinkedIn", systemImage: "link")
                    .foregroundStyle(.cyan)
                    .font(.headline)
                Spacer()
                Text(content.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(content.title)
                .font(.title3)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)

            if !content.summary.isEmpty {
                Text(content.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
            }

            if let imageURL = content.imageURL {
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
                            .frame(height: 160)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 120)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LinkedInPreviewView(
        content: LinkedInContent(
            title: "Scaling SwiftUI applications for enterprise teams",
            summary: "Best practices for building accessible and collaborative experiences.",
            imageURL: URL(string: "https://images.example.com/linkedin-preview.jpg"),
            author: "urn:li:person:example"
        )
    )
    .padding()
}
