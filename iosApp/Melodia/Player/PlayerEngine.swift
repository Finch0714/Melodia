import AVFoundation
import Combine
import MediaPlayer

@MainActor
final class PlayerEngine: ObservableObject {
    @Published private(set) var currentTrack: Track?
    @Published private(set) var queue: [Track] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var lyrics: [LyricLine] = []
    @Published private(set) var currentLyricIndex = -1
    @Published var errorMessage: String?

    private let player = AVPlayer()
    private let client = NeteaseClient.shared
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var loadTask: Task<Void, Never>?

    init() {
        configureAudioSession()
        configureRemoteCommands()
        installObservers()
        player.actionAtItemEnd = .pause
    }

    var hasNext: Bool { queue.count > 1 }
    var hasPrevious: Bool { queue.count > 1 }

    var currentLyric: LyricLine? {
        guard lyrics.indices.contains(currentLyricIndex) else { return nil }
        return lyrics[currentLyricIndex]
    }

    func play(_ track: Track, queue: [Track]? = nil) {
        let resolvedQueue = (queue?.isEmpty == false ? queue! : [track])
        self.queue = resolvedQueue.contains(where: { $0.id == track.id }) ? resolvedQueue : [track] + resolvedQueue
        currentIndex = self.queue.firstIndex(where: { $0.id == track.id }) ?? 0
        start(track: track)
    }

    func playAll(_ tracks: [Track], startAt index: Int = 0) {
        guard !tracks.isEmpty, tracks.indices.contains(index) else { return }
        queue = tracks
        currentIndex = index
        start(track: tracks[index])
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func resume() {
        guard player.currentItem != nil else { return }
        activateAudioSession()
        player.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func next() {
        guard !queue.isEmpty else { return }
        currentIndex = (currentIndex + 1) % queue.count
        start(track: queue[currentIndex])
    }

    func previous() {
        if currentTime > 4 {
            seek(to: 0)
            return
        }
        guard !queue.isEmpty else { return }
        currentIndex = (currentIndex - 1 + queue.count) % queue.count
        start(track: queue[currentIndex])
    }

    func seek(to seconds: Double) {
        guard seconds.isFinite else { return }
        let target = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = max(0, seconds)
        updateCurrentLyric()
        updateNowPlayingInfo()
    }

    func clearError() {
        errorMessage = nil
    }

    private func start(track: Track) {
        loadTask?.cancel()
        currentTrack = track
        currentTime = 0
        duration = Double(track.durationMs) / 1000
        lyrics = []
        currentLyricIndex = -1
        isLoading = true
        errorMessage = nil

        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.load(track: track)
        }
    }

    private func load(track: Track) async {
        do {
            let url = try await client.songURL(id: track.id)
            guard !Task.isCancelled, currentTrack?.id == track.id else { return }
            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            activateAudioSession()
            player.play()
            isPlaying = true
            isLoading = false
            updateNowPlayingInfo()
            Task { [weak self] in
                guard let self else { return }
                await self.loadLyrics(songID: track.id)
            }
        } catch {
            guard currentTrack?.id == track.id else { return }
            isLoading = false
            isPlaying = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            updateNowPlayingInfo()
        }
    }

    private func loadLyrics(songID: Int64) async {
        do {
            let response = try await client.lyrics(songID: songID)
            guard currentTrack?.id == songID else { return }
            lyrics = LyricParser.parse(response: response)
            updateCurrentLyric()
        } catch {
            guard currentTrack?.id == songID else { return }
            lyrics = []
            currentLyricIndex = -1
        }
    }

    private func installObservers() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = max(0, time.seconds)
                if let item = self.player.currentItem {
                    let itemDuration = item.duration.seconds
                    if itemDuration.isFinite, itemDuration > 0 {
                        self.duration = itemDuration
                    }
                }
                self.updateCurrentLyric()
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      let item = notification.object as? AVPlayerItem,
                      item === self.player.currentItem else { return }
                self.next()
            }
        }
    }

    private func updateCurrentLyric() {
        guard !lyrics.isEmpty else {
            currentLyricIndex = -1
            return
        }
        var index = 0
        for (offset, line) in lyrics.enumerated() {
            if line.time <= currentTime + 0.18 {
                index = offset
            } else {
                break
            }
        }
        currentLyricIndex = index
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
    }

    private func activateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = track.name
        info[MPMediaItemPropertyArtist] = track.artistText
        info[MPMediaItemPropertyAlbumTitle] = track.albumName
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                _ = self?.resume()
            }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                _ = self?.pause()
            }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                _ = self?.next()
            }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                _ = self?.previous()
            }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                _ = self?.seek(to: event.positionTime)
            }
            return .success
        }
    }
}
