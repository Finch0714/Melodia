import SwiftUI
import UIKit

struct RootView: View {
    @StateObject private var appModel = AppModel()
    @StateObject private var player = PlayerEngine()
    @State private var selectedTab = 0
    @State private var showNowPlaying = false
    @AppStorage(MelodiaSettings.keepScreenAwakeKey) private var keepScreenAwake = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(onOpenAccount: { selectedTab = 2 })
                    .tabItem {
                        Label("首页", systemImage: "house.fill")
                    }
                    .tag(0)

                SearchView()
                    .tabItem {
                        Label("搜索", systemImage: "magnifyingglass")
                    }
                    .tag(1)

                AccountView()
                    .tabItem {
                        Label("我的", systemImage: "person.crop.circle")
                    }
                    .tag(2)

                NavigationStack {
                    MoreView()
                }
                .tabItem {
                    Label("更多", systemImage: "ellipsis.circle.fill")
                }
                .tag(3)
            }
            .toolbarBackground(MelodiaTheme.backgroundRaised, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)

            if player.currentTrack != nil && !showNowPlaying {
                MiniPlayer(showNowPlaying: $showNowPlaying)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 58)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environmentObject(appModel)
        .environmentObject(player)
        .background(MelodiaTheme.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView()
                .environmentObject(player)
                .environmentObject(appModel)
        }
        .task {
            await appModel.bootstrap()
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = keepScreenAwake
        }
        .onChange(of: keepScreenAwake) { newValue in
            UIApplication.shared.isIdleTimerDisabled = newValue
        }
        .alert("播放失败", isPresented: playerErrorBinding) {
            Button("好") {
                player.clearError()
            }
        } message: {
            Text(player.errorMessage ?? "")
        }
    }

    private var playerErrorBinding: Binding<Bool> {
        Binding(
            get: { player.errorMessage != nil },
            set: { value in
                if !value { player.clearError() }
            }
        )
    }
}