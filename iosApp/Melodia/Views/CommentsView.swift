import Foundation
import SwiftUI

struct CommentsView: View {
    let track: Track

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    @State private var comments: [CommentItem] = []
    @State private var totalCount = 0
    @State private var page = 1
    @State private var hasMore = false
    @State private var sortType = 99
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var actionError: String?
    @State private var showLoginHint = false
    @State private var floorParent: CommentItem?
    @State private var composerTarget: CommentComposerTarget?

    private let client = NeteaseClient.shared

    private var threadID: String { "R_SO_4_\(track.id)" }

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
                    if let actionError {
                        ErrorBanner(message: actionError)
                    }

                    if isLoading && comments.isEmpty {
                        ProgressView("正在加载评论…")
                            .tint(MelodiaTheme.accentSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 70)
                    } else if comments.isEmpty {
                        EmptyStateView(
                            icon: "bubble.left",
                            title: "还没有评论",
                            message: "来做第一个留下感想的人"
                        )
                    } else {
                        Text("共 \(max(totalCount, comments.count)) 条评论")
                            .font(.caption)
                            .foregroundStyle(MelodiaTheme.textTertiary)

                        ForEach(comments) { comment in
                            CommentRowView(
                                comment: comment,
                                isReplying: false,
                                onOpenFloor: { floorParent = comment },
                                onReply: { openComposer(replyingTo: comment) },
                                onLike: { toggleLike(comment) }
                            )
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

                    Color.clear.frame(height: 20)
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
            .safeAreaInset(edge: .bottom) {
                commentComposerBar
            }
            .task { await load(reset: true) }
            .refreshable { await load(reset: true) }
        }
        .sheet(item: $floorParent) { parent in
            CommentFloorView(track: track, parent: parent, threadID: threadID)
                .environmentObject(appModel)
        }
        .sheet(item: $composerTarget) { target in
            CommentComposerSheet(target: target) { _ in
                Task { await load(reset: true) }
            }
            .environmentObject(appModel)
        }
        .alert("需要登录", isPresented: $showLoginHint) {
            Button("好", role: .cancel) {}
        } message: {
            Text("发表评论和回复前，请先在「我的」页面登录网易云账号。")
        }
    }

    private var commentComposerBar: some View {
        HStack(spacing: 10) {
            Button {
                openComposer(replyingTo: nil)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .semibold))
                    Text("说点什么…")
                        .font(.footnote.weight(.medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(MelodiaTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.white.opacity(0.07), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func openComposer(replyingTo comment: CommentItem?) {
        guard appModel.isLoggedIn else {
            showLoginHint = true
            return
        }
        composerTarget = CommentComposerTarget(
            threadID: threadID,
            replyCommentID: comment?.commentId,
            replyingTo: comment?.user.nickname
        )
    }

    private func toggleLike(_ comment: CommentItem) {
        guard appModel.isLoggedIn else {
            showLoginHint = true
            return
        }
        let targetLiked = !comment.liked
        Task {
            do {
                try await client.likeComment(
                    threadID: threadID,
                    commentID: comment.commentId,
                    like: targetLiked
                )
                await MainActor.run {
                    guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }
                    comments[index].liked = targetLiked
                    comments[index].likedCount = max(0, comments[index].likedCount + (targetLiked ? 1 : -1))
                }
            } catch {
                await MainActor.run {
                    actionError = friendlyMessage(error)
                }
            }
        }
    }

    private func load(reset: Bool) async {
        if reset {
            isLoading = true
            errorMessage = nil
            actionError = nil
            page = 1
        } else {
            isLoadingMore = true
        }

        do {
            let data = try await client.comments(
                threadID: threadID,
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
            if reset {
                comments = []
            }
            errorMessage = friendlyMessage(error)
        }

        isLoading = false
        isLoadingMore = false
    }
}

private struct CommentRowView: View {
    let comment: CommentItem
    let isReplying: Bool
    let onOpenFloor: () -> Void
    let onReply: () -> Void
    let onLike: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CoverImage(url: comment.user.avatarURL, size: isReplying ? 34 : 40, cornerRadius: 20)
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

                if let replied = comment.beReplied?.first,
                   let content = replied.content,
                   !content.isEmpty {
                    Text("回复 @\(replied.user?.nickname ?? "用户")：\(content)")
                        .font(.caption)
                        .foregroundStyle(MelodiaTheme.textTertiary)
                        .lineLimit(2)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                Text(comment.content)
                    .font(.subheadline)
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 18) {
                    if comment.replyCount > 0 {
                        Button(action: onOpenFloor) {
                            Label("查看 \(comment.replyCount) 条回复", systemImage: "bubble.left.and.bubble.right")
                        }
                    }

                    Button(action: onReply) {
                        Label("回复", systemImage: "arrowshape.turn.up.left")
                    }

                    Button(action: onLike) {
                        Label(
                            comment.likedCount > 0 ? "\(comment.likedCount)" : "赞",
                            systemImage: comment.liked ? "heart.fill" : "heart"
                        )
                    }
                }
                .font(.caption2)
                .foregroundStyle(MelodiaTheme.textTertiary)
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
    }
}

private struct CommentFloorView: View {
    let track: Track
    let parent: CommentItem
    let threadID: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    @State private var comments: [CommentItem] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMore = false
    @State private var nextTime: Int64 = -1
    @State private var errorMessage: String?
    @State private var showLoginHint = false
    @State private var composerTarget: CommentComposerTarget?

    private let client = NeteaseClient.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    CommentRowView(
                        comment: parent,
                        isReplying: false,
                        onOpenFloor: {},
                        onReply: { openComposer(replyingTo: parent) },
                        onLike: {}
                    )
                    .padding(.horizontal, 18)

                    Divider().overlay(MelodiaTheme.divider).padding(.horizontal, 18)

                    if let errorMessage {
                        ErrorBanner(message: errorMessage).padding(.horizontal, 18)
                    }

                    if comments.count > 0 {
                        Text("共 \(comments.count)\(hasMore ? "+" : "") 条回复")
                            .font(.caption)
                            .foregroundStyle(MelodiaTheme.textTertiary)
                            .padding(.horizontal, 18)
                    }

                    if isLoading && comments.isEmpty {
                        ProgressView("正在加载回复…")
                            .tint(MelodiaTheme.accentSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 50)
                    } else if comments.isEmpty {
                        EmptyStateView(
                            icon: "bubble.left.and.bubble.right",
                            title: "还没有回复",
                            message: "来回复这条评论"
                        )
                    } else {
                        ForEach(comments) { comment in
                            CommentRowView(
                                comment: comment,
                                isReplying: true,
                                onOpenFloor: {},
                                onReply: { openComposer(replyingTo: comment) },
                                onLike: { toggleLike(comment) }
                            )
                            .padding(.horizontal, 18)
                            Divider().overlay(MelodiaTheme.divider).padding(.leading, 64)
                        }

                        if hasMore {
                            Button {
                                Task { await load(more: true) }
                            } label: {
                                HStack {
                                    if isLoadingMore {
                                        ProgressView().tint(MelodiaTheme.accentSoft)
                                    }
                                    Text(isLoadingMore ? "加载中…" : "加载更多回复")
                                        .font(.footnote.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(MelodiaTheme.surface, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingMore)
                            .padding(.horizontal, 18)
                        }
                    }

                    Color.clear.frame(height: 12)
                }
                .padding(.top, 10)
            }
            .scrollIndicators(.hidden)
            .background(MelodiaTheme.background.ignoresSafeArea())
            .navigationTitle("评论回复")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(MelodiaTheme.textPrimary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    openComposer(replyingTo: parent)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                        Text("回复 @\(parent.user.nickname)")
                        Spacer(minLength: 0)
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.07), in: Capsule())
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }
                .buttonStyle(.plain)
            }
            .task { await load(more: false) }
        }
        .sheet(item: $composerTarget) { target in
            CommentComposerSheet(target: target) { _ in
                Task { await load(more: false) }
            }
            .environmentObject(appModel)
        }
        .alert("需要登录", isPresented: $showLoginHint) {
            Button("好", role: .cancel) {}
        } message: {
            Text("回复评论前，请先在「我的」页面登录网易云账号。")
        }
    }

    private func openComposer(replyingTo comment: CommentItem) {
        guard appModel.isLoggedIn else {
            showLoginHint = true
            return
        }
        composerTarget = CommentComposerTarget(
            threadID: threadID,
            replyCommentID: comment.commentId,
            replyingTo: comment.user.nickname
        )
    }

    private func toggleLike(_ comment: CommentItem) {
        guard appModel.isLoggedIn else {
            showLoginHint = true
            return
        }
        let targetLiked = !comment.liked
        Task {
            do {
                try await client.likeComment(
                    threadID: threadID,
                    commentID: comment.commentId,
                    like: targetLiked
                )
                await MainActor.run {
                    guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }
                    comments[index].liked = targetLiked
                    comments[index].likedCount = max(0, comments[index].likedCount + (targetLiked ? 1 : -1))
                }
            } catch {
                await MainActor.run { errorMessage = friendlyMessage(error) }
            }
        }
    }

    private func load(more: Bool) async {
        if more {
            isLoadingMore = true
        } else {
            isLoading = true
            errorMessage = nil
            nextTime = -1
        }

        do {
            let data = try await client.commentFloors(
                parentCommentID: parent.commentId,
                threadID: threadID,
                time: more ? nextTime : -1,
                limit: 20
            )
            if more {
                comments.append(contentsOf: data.comments)
            } else {
                comments = data.comments
            }
            hasMore = data.hasMore
            nextTime = data.comments.last?.time ?? nextTime
        } catch {
            errorMessage = friendlyMessage(error)
            if !more { comments = [] }
        }

        isLoading = false
        isLoadingMore = false
    }
}

struct CommentComposerTarget: Identifiable {
    let id = UUID()
    let threadID: String
    let replyCommentID: Int64?
    let replyingTo: String?
}

private struct CommentComposerSheet: View {
    let target: CommentComposerTarget
    let onPosted: (CommentItem?) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel
    @State private var text = ""
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var showLoginHint = false

    private let client = NeteaseClient.shared
    private let limit = 500

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if let replyingTo = target.replyingTo {
                    Text("回复 @\(replyingTo)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(MelodiaTheme.accentSoft)
                }

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("写下你的想法…")
                            .font(.body)
                            .foregroundStyle(MelodiaTheme.textTertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                    }
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(MelodiaTheme.textPrimary)
                        .frame(minHeight: 180)
                        .onChange(of: text) { value in
                            if value.count > limit {
                                text = String(value.prefix(limit))
                            }
                        }
                }
                .padding(12)
                .background(MelodiaTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack {
                    Text("\(text.count)/\(limit)")
                        .font(.caption2)
                        .foregroundStyle(MelodiaTheme.textTertiary)
                    Spacer()
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundStyle(MelodiaTheme.accentSoft)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(18)
            .background(MelodiaTheme.background.ignoresSafeArea())
            .navigationTitle(target.replyCommentID == nil ? "发表评论" : "回复评论")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(MelodiaTheme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isPosting {
                            ProgressView().tint(MelodiaTheme.accentSoft)
                        } else {
                            Text("发送").fontWeight(.semibold)
                        }
                    }
                    .disabled(isPosting || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundStyle(MelodiaTheme.accentSoft)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .alert("需要登录", isPresented: $showLoginHint) {
            Button("好", role: .cancel) {}
        } message: {
            Text("发表评论前，请先在「我的」页面登录网易云账号。")
        }
    }

    private func submit() async {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        guard appModel.isLoggedIn else {
            showLoginHint = true
            return
        }

        isPosting = true
        errorMessage = nil
        do {
            let comment: CommentItem?
            if let commentID = target.replyCommentID {
                comment = try await client.replyComment(
                    threadID: target.threadID,
                    commentID: commentID,
                    content: content
                )
            } else {
                comment = try await client.addComment(
                    threadID: target.threadID,
                    content: content
                )
            }
            onPosted(comment)
            dismiss()
        } catch {
            errorMessage = friendlyMessage(error)
        }
        isPosting = false
    }
}

private func relativeTime(_ timestamp: Int64) -> String {
    guard timestamp > 0 else { return "" }
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}

private func friendlyMessage(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
}