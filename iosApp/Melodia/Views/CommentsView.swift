import Foundation
import SwiftUI

struct CommentsView: View {
    let track: Track

    @Environment(\.dismiss) private var dismiss
    @State private var comments: [CommentItem] = []
    @State private var totalCount = 0
    @State private var page = 1
    @State private var hasMore = false
    @State private var sortType = 99
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?

    private let client = NeteaseClient.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("排序", selection: $sortType) {
                        Text("推荐").tag(99)
                        Text("最热").tag(2)
                        Text("最新").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: sortType) { _ in
                        Task { await load(reset: true) }
                    }

                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    if isLoading && comments.isEmpty {
                        ProgressView("正在加载评论…")
                            .tint(MelodiaTheme.accentSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 70)
                    } else if comments.isEmpty {
                        EmptyStateView(icon: "bubble.left", title: "还没有评论", message: "来做第一个留下感想的人")
                    } else {
                        Text("共 \(totalCount) 条评论")
                            .font(.caption)
                            .foregroundStyle(MelodiaTheme.textTertiary)

                        ForEach(comments) { comment in
                            commentRow(comment)
                            Divider().overlay(MelodiaTheme.divider)
                        }

                        if hasMore {
                            Button {
                                Task { await load(reset: false) }
                            } label: {
                                HStack {
                                    if isLoadingMore {
                                        ProgressView()
                                            .tint(MelodiaTheme.accentSoft)
                                    }
                                    Text(isLoadingMore ? "加载中…" : "加载更多评论")
                                        .font(.footnote.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(MelodiaTheme.surface, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingMore)
                        }
                    }

                    Color.clear.frame(height: 70)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
            }
            .scrollIndicators(.hidden)
            .background(MelodiaTheme.background.ignoresSafeArea())
            .navigationTitle("歌曲评论")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(MelodiaTheme.textPrimary)
                }
            }
            .task { await load(reset: true) }
        }
    }

    private func commentRow(_ comment: CommentItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            CoverImage(url: comment.user.avatarURL, size: 40, cornerRadius: 20)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(comment.user.nickname)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(MelodiaTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(relativeTime(comment.time))
                        .font(.caption2)
                        .foregroundStyle(MelodiaTheme.textTertiary)
                }

                Text(comment.content)
                    .font(.subheadline)
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 14) {
                    if comment.replyCount > 0 {
                        Label("\(comment.replyCount)", systemImage: "bubble.left")
                    }
                    Label("\(comment.likedCount)", systemImage: comment.liked ? "heart.fill" : "heart")
                }
                .font(.caption2)
                .foregroundStyle(MelodiaTheme.textTertiary)
            }
        }
        .padding(.vertical, 10)
    }

    private func load(reset: Bool) async {
        if reset {
            isLoading = true
            errorMessage = nil
            page = 1
        } else {
            isLoadingMore = true
        }

        do {
            let data = try await client.comments(
                threadID: "R_SO_4_\(track.id)",
                page: page,
                sortType: sortType
            )
            if reset {
                comments = data.comments
            } else {
                comments.append(contentsOf: data.comments)
            }
            totalCount = max(data.totalCount, comments.count)
            hasMore = data.hasMore
            page += 1
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            if reset {
                comments = []
            }
        }

        isLoading = false
        isLoadingMore = false
    }

    private func relativeTime(_ timestamp: Int64) -> String {
        guard timestamp > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}