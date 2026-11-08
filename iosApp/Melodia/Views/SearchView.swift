import Foundation
import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var player: PlayerEngine
    @State private var query = ""
    @State private var results: [Track] = []
    @State private var isSearching = false
    @State private var didSearch = false
    @State private var errorMessage: String?
    @State private var history: [String] = []
    @State private var generation = 0

    private let client = NeteaseClient.shared
    private let historyKey = "melodia.search.history"
    private let suggestions = ["周杰伦", "林俊杰", "Taylor Swift", "华语流行", "轻音乐"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        discoveryContent
                    } else if isSearching && results.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView("正在搜索…")
                                .tint(MelodiaTheme.accentSoft)
                                .padding(.vertical, 70)
                            Spacer()
                        }
                    } else if results.isEmpty && didSearch {
                        EmptyStateView(icon: "magnifyingglass", title: "没有找到歌曲", message: "换一个关键词试试")
                    } else if !results.isEmpty {
                        resultsContent
                    }

                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .background(MelodiaTheme.background.ignoresSafeArea())
            .navigationTitle("搜索")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索歌曲、歌手")
            .submitLabel(.search)
            .onSubmit(of: .search) {
                Task { await search() }
            }
        }
    }

    private var discoveryContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "最近搜索")
                    chipCloud(history) { keyword in
                        query = keyword
                        Task { await search(keyword: keyword) }
                    }
                    Button("清空记录") {
                        history = []
                        UserDefaults.standard.removeObject(forKey: historyKey)
                    }
                    .font(.caption)
                    .foregroundStyle(MelodiaTheme.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "热门搜索", subtitle: "从这些开始")
                chipCloud(suggestions) { keyword in
                    query = keyword
                    Task { await search(keyword: keyword) }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("音乐应该简单一点")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                Text("搜索歌曲后即可直接播放，支持网易云曲库、歌词和后台播放。")
                    .font(.subheadline)
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .lineSpacing(4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [MelodiaTheme.accent.opacity(0.28), MelodiaTheme.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
        }
        .onAppear(perform: loadHistory)
    }

    private var resultsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "搜索结果", subtitle: "\(results.count) 首")
                Spacer()
                Button {
                    player.playAll(results)
                } label: {
                    Label("播放", systemImage: "play.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(MelodiaTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.offset) { index, track in
                    TrackRow(track: track, queue: results, number: index + 1)
                    if index < results.count - 1 {
                        Divider().overlay(MelodiaTheme.divider)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .melodiaCard()
        }
    }

    private func chipCloud(_ values: [String], action: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(values, id: \.self) { value in
                Button {
                    action(value)
                } label: {
                    Text(value)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(MelodiaTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(MelodiaTheme.surface, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func search(keyword: String? = nil) async {
        if let keyword { query = keyword }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        generation += 1
        let current = generation
        isSearching = true
        didSearch = true
        errorMessage = nil
        do {
            let songs = try await client.searchSongs(keyword: trimmed)
            guard current == generation else { return }
            results = songs
            saveHistory(trimmed)
        } catch {
            guard current == generation else { return }
            results = []
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        if current == generation {
            isSearching = false
        }
    }

    private func loadHistory() {
        history = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
    }

    private func saveHistory(_ keyword: String) {
        var values = history.filter { $0 != keyword }
        values.insert(keyword, at: 0)
        history = Array(values.prefix(10))
        UserDefaults.standard.set(history, forKey: historyKey)
    }
}
