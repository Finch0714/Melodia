import Foundation
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var player: PlayerEngine

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero

                    if let error = appModel.homeError {
                        ErrorBanner(message: error)
                    }

                    recommendationSection
                    dailySection
                    toplistSection

                    Color.clear.frame(height: 96)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .background(
                ZStack {
                    MelodiaTheme.background
                    MelodiaTheme.heroGradient
                        .frame(height: 360)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea()
                }
            )
            .refreshable {
                await appModel.loadHome()
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: PlaylistRoute.self) { route in
                PlaylistView(route: route)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(greeting)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MelodiaTheme.textSecondary)
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MelodiaTheme.accentSoft)
                    .padding(10)
                    .background(Color.white.opacity(0.06), in: Circle())
            }

            Text("Melodia")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(MelodiaTheme.textPrimary)

            Text("把今天交给音乐")
                .font(.subheadline)
                .foregroundStyle(MelodiaTheme.textSecondary)
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "为你推荐", subtitle: "从网易云挑选的今日灵感")
            if appModel.isLoadingHome && appModel.homePlaylists.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LoadingCards()
                }
            } else if appModel.homePlaylists.isEmpty {
                EmptyStateView(icon: "sparkles", title: "暂时没有推荐", message: "下拉刷新试试")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(Array(appModel.homePlaylists.prefix(12))) { playlist in
                            PlaylistCard(playlist: playlist)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var dailySection: some View {
        if !appModel.dailySongs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    SectionTitle(title: "每日推荐", subtitle: "根据你的口味生成")
                    Spacer()
                    Button {
                        player.playAll(appModel.dailySongs)
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
                    ForEach(Array(appModel.dailySongs.prefix(6).enumerated()), id: \.element.id) { index, track in
                        TrackRow(track: track, queue: appModel.dailySongs, number: index + 1)
                        if index < min(6, appModel.dailySongs.count) - 1 {
                            Divider().overlay(MelodiaTheme.divider)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .melodiaCard()
            }
        }
    }

    private var toplistSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "排行榜", subtitle: "此刻大家都在听")
            if appModel.toplists.isEmpty {
                if appModel.isLoadingHome {
                    LoadingCards()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(Array(appModel.toplists.prefix(12))) { playlist in
                            PlaylistCard(playlist: playlist)
                        }
                    }
                }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "早上好"
        case 12..<18: return "下午好"
        default: return "晚上好"
        }
    }
}
